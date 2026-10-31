export async function checkLegacyMigration(db, orders, assert) {
  const current = async (id) =>
    (await db.query(
      "select * from public.membership_renewal_requests where id=$1",
      [id],
    )).rows[0];
  assert(
    (await current(orders[0].id)).payment_provider === "legacy_review",
    "Ambiguous legacy MoMo must not become proven manual when Business was disabled after a timeout",
  );
  await db.exec(
    `select set_config('request.jwt.claim.sub','${orders[0].user_id}',false);
    select set_config('request.jwt.claim.role','authenticated',false); set role authenticated`,
  );
  let denied = false;
  try {
    await db.query("select public.cancel_own_membership_request($1)", [
      orders[0].id,
    ]);
  } catch {
    denied = true;
  }
  assert(denied, "Ambiguous legacy attempt must not allow client cancellation");
  await db.exec(
    "reset role; select set_config('request.jwt.claim.role','service_role',false)",
  );
  await db.query(
    "update public.membership_renewal_requests set payment_expires_at=now()-interval '1 hour' where id=$1",
    [orders[0].id],
  );
  await db.query("select public.apply_momo_result($1,$2,42,null,true)", [
    orders[0].id,
    orders[0].amount,
  ]);
  assert(
    (await current(orders[0].id)).status === "pending",
    "Missing gateway order does not disprove a legacy personal transfer",
  );
  await db.query("select public.apply_momo_result($1,$2,0,'8888',false)", [
    orders[0].id,
    orders[0].amount,
  ]);
  assert(
    (await current(orders[0].id)).status === "approved" &&
      (await current(orders[0].id)).payment_provider === "momo_business",
    "Genuine late legacy gateway success remains recoverable",
  );
  await db.query(
    "select public.resolve_legacy_membership_payment($1,'manual')",
    [orders[1].id],
  );
  await db.exec(
    `select set_config('request.jwt.claim.sub','${orders[1].user_id}',false);
    select set_config('request.jwt.claim.role','authenticated',false); set role authenticated`,
  );
  await db.query("select public.cancel_own_membership_request($1)", [
    orders[1].id,
  ]);
  await db.exec(
    "reset role; select set_config('request.jwt.claim.role','service_role',false)",
  );
  console.log(
    "PASS: legacy timeout with Business disabled, guarded classification and late signed payment recovery.",
  );
}

export async function checkPaymentLifecycle(db, uid, other, assert) {
  const pkg = "33333333-3333-4333-8333-333333333333";
  const service = async () =>
    db.exec(
      `reset role; select set_config('request.jwt.claim.role','service_role',false)`,
    );
  const member = async (id = uid) =>
    db.exec(
      `reset role; select set_config('request.jwt.claim.sub','${id}',false); select set_config('request.jwt.claim.role','authenticated',false); set role authenticated`,
    );
  const denied = async (fn, message) => {
    let failed = false;
    try {
      await fn();
    } catch {
      failed = true;
    }
    assert(failed, message);
  };
  const order = async (method = "online") => {
    await member();
    return (await db.query(
      `insert into public.membership_renewal_requests(user_id,package_id,payment_method,payment_provider,gateway_started_at,payment_expires_at) values($1,$2,$3,'manual',now(),now() - interval '1 day') returning *`,
      [uid, pkg, method],
    )).rows[0];
  };
  const result = async (
    id,
    code,
    transaction = null,
    missing = false,
    amount = 100000,
  ) => {
    await service();
    return db.query("select public.apply_momo_result($1,$2,$3,$4,$5)", [
      id,
      amount,
      code,
      transaction,
      missing,
    ]);
  };
  const saved = async (id) =>
    (await db.query(
      "select * from public.membership_renewal_requests where id=$1",
      [id],
    )).rows[0];
  await service();
  await db.exec("update public.payment_settings set online_enabled=true");
  const business = await order();
  assert(
    business.payment_provider === "momo_business" &&
      business.gateway_started_at === null,
    "Client must not forge provider or create-claim fields",
  );
  assert(
    new Date(business.payment_expires_at) > new Date(),
    "Client must not forge expiry",
  );
  await member(other);
  await denied(
    () => db.query("select public.claim_membership_payment($1)", [business.id]),
    "Member cannot claim a gateway session",
  );
  await denied(
    () =>
      db.query("select public.apply_momo_result($1,100000,0,'44',false)", [
        business.id,
      ]),
    "Member cannot confirm payments",
  );
  await denied(
    () =>
      db.query("select public.cancel_own_membership_request($1)", [
        business.id,
      ]),
    "Other account cannot cancel",
  );
  await service();
  assert(
    (await db.query("select public.claim_membership_payment($1) as claimed", [
      business.id,
    ])).rows[0].claimed,
    "First caller claims create",
  );
  assert(
    !(await db.query("select public.claim_membership_payment($1) as claimed", [
      business.id,
    ])).rows[0].claimed,
    "Retry cannot create another session",
  );
  await member();
  await denied(
    () =>
      db.query("select public.cancel_own_membership_request($1)", [
        business.id,
      ]),
    "Attempted Business order requires reconciliation",
  );
  await service();
  await db.query(
    "update public.membership_renewal_requests set payment_expires_at=now()-interval '1 hour' where id=$1",
    [business.id],
  );
  for (
    const code of [10, 11, 13, 40, 41, 43, 99, 1000, 7000, 7002, 9000, 99999]
  ) {
    await result(business.id, code);
    assert(
      (await saved(business.id)).status === "pending",
      `Code ${code} must not falsely reject unpaid/unknown/processing order`,
    );
  }
  await result(business.id, 1005);
  assert(
    (await saved(business.id)).status === "expired",
    "Verified gateway expiry releases the pending slot",
  );
  const replacement = await order("cash");
  const before = (await db.query(
    "select count(*)::int as n from public.app_notifications where user_id=$1",
    [uid],
  ))
    .rows[0].n;
  await result(business.id, 0, "555");
  await result(business.id, 0, "555");
  await result(business.id, 1006);
  assert(
    (await saved(business.id)).status === "approved",
    "Late success wins over closed/failure state",
  );
  assert(
    (await saved(replacement.id)).status === "pending",
    "Late success must not discard another pending order",
  );
  assert(
    (await db.query(
      "select count(*)::int as n from public.app_notifications where user_id=$1",
      [uid],
    ))
      .rows[0].n === before + 1,
    "Duplicate success must notify only once",
  );
  await denied(
    () => result(business.id, 0, "556"),
    "Different transaction cannot overwrite approval",
  );
  await denied(
    () => result(business.id, 0, "555", false, 1),
    "Wrong amount cannot activate",
  );
  await denied(
    () => result(replacement.id, 0, "557"),
    "Manual payment cannot auto-activate",
  );
  await member();
  await db.query("select public.cancel_own_membership_request($1)", [
    replacement.id,
  ]);
  assert(
    (await saved(replacement.id)).status === "cancelled",
    "Manual cancel has a truthful state",
  );

  const missing = await order();
  await service();
  await db.query("select public.claim_membership_payment($1)", [missing.id]);
  await result(missing.id, 42, null, true);
  assert(
    (await saved(missing.id)).status === "pending",
    "Not found during create uncertainty must stay pending",
  );
  await db.query(
    "update public.membership_renewal_requests set payment_expires_at=now()-interval '6 minutes' where id=$1",
    [missing.id],
  );
  await result(missing.id, 42, null, false);
  assert(
    (await saved(missing.id)).status === "pending",
    "IPN cannot use query-only not-found evidence",
  );
  await result(missing.id, 42, null, true);
  assert(
    (await saved(missing.id)).status === "expired",
    "Missing gateway order can close after deadline and grace",
  );
  assert(
    !(await db.query("select public.claim_membership_payment($1) as claimed", [
      missing.id,
    ])).rows[0].claimed,
    "Closed missing order must never create later",
  );

  const manual = await order("bank_transfer");
  await service();
  await db.exec("update public.payment_settings set online_enabled=false");
  await member();
  await db.query("select public.cancel_own_membership_request($1)", [
    manual.id,
  ]);
  const personal = await order();
  await service();
  await db.exec("update public.payment_settings set online_enabled=true");
  await member();
  await db.query("select public.cancel_own_membership_request($1)", [
    personal.id,
  ]);
  assert(
    personal.payment_provider === "manual",
    "Personal MoMo keeps manual provider despite settings toggle",
  );
  const atomic = await order();
  await service();
  const oldContracts = (await db.query(
    "select id,end_date,active from public.memberships where user_id=$1 order by id",
    [uid],
  )).rows;
  await db.exec(
    `create function public.test_reject_notice() returns trigger language plpgsql as $$
    begin raise exception 'Simulated notification failure'; end $$;
    create trigger test_reject_notice before insert on public.app_notifications
    for each row execute function public.test_reject_notice()`,
  );
  await denied(
    () => result(atomic.id, 0, "999"),
    "Notification failure must roll back payment activation",
  );
  assert(
    (await saved(atomic.id)).status === "pending" &&
      (await saved(atomic.id)).transaction_no === null,
    "Failed activation must retain retryable order without a transaction marker",
  );
  assert(
    JSON.stringify(
      (await db.query(
        "select id,end_date,active from public.memberships where user_id=$1 order by id",
        [uid],
      )).rows,
    ) === JSON.stringify(oldContracts),
    "Failed activation must preserve previous contract and dates",
  );
  await db.exec(
    "drop trigger test_reject_notice on public.app_notifications; drop function public.test_reject_notice()",
  );
  await denied(
    () => result(atomic.id, 0, "555"),
    "One gateway transaction cannot activate a different order",
  );
  await result(atomic.id, 0, "999");
  await member();
  await denied(
    () =>
      db.query(
        "update public.membership_renewal_requests set status='approved' where id=$1",
        [atomic.id],
      ),
    "Member cannot update payment lifecycle directly",
  );
  await denied(
    () =>
      db.query(
        "update public.memberships set used_sessions=used_sessions+1 where user_id=$1",
        [uid],
      ),
    "Member cannot fabricate gym visit counters",
  );
  await service();
  console.log(
    "PASS: provider snapshot, ownership, single create, uncertainty, expiry, late/duplicate IPN, atomic activation and manual cancellation.",
  );
}
