import { fileURLToPath } from "node:url";
process.chdir(fileURLToPath(new URL("../../", import.meta.url)));
import { PGlite } from "@electric-sql/pglite";
import { readFile } from "node:fs/promises";
const db = new PGlite();
const assert = (ok, message) => {
  if (!ok) throw new Error(message);
};
await db.exec(`
create role anon; create role authenticated; create role service_role bypassrls;
create schema auth;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create function auth.role() returns text language sql stable as $$ select current_setting('request.jwt.claim.role',true) $$;
grant usage on schema auth to authenticated,service_role;
grant execute on all functions in schema auth to authenticated,service_role;
`);
for (
  const migration of [
    "20261029000000_initial_schema.sql",
    "20261030000000_tracking_and_sync.sql",
    "20261030010000_app_improvements.sql",
    "20261030020000_real_member_flows.sql",
    "20261030030000_payment_methods.sql",
    "20261030040000_gym_packages.sql",
  ]
) {
  if (process.argv.includes("--bundle") && migration >= "20261030020000") {
    continue;
  }
  await db.exec(await readFile(`supabase/migrations/${migration}`, "utf8"));
  console.log("Migration OK:", migration);
}
if (process.argv.includes("--bundle")) {
  await db.exec(await readFile("supabase/APPLY_UPGRADE.sql", "utf8"));
  console.log("Combined upgrade OK");
}
await db.exec("create publication supabase_realtime");
await db.exec(
  await readFile(
    "supabase/migrations/20261030050000_live_payment_updates.sql",
    "utf8",
  ),
);
await db.exec(
  await readFile(
    "supabase/migrations/20261101000000_atomic_workout_sync.sql",
    "utf8",
  ),
);
await db.exec(
  await readFile(
    "supabase/migrations/20261101010000_workout_duration_sync.sql",
    "utf8",
  ),
);
console.log("Atomic workout sync migration OK");
await db.exec(
  await readFile(
    "supabase/migrations/20261030050000_live_payment_updates.sql",
    "utf8",
  ),
);
assert(
  (await db.query(
    "select * from pg_publication_tables where pubname='supabase_realtime'",
  )).rows.length === 3,
  "Realtime must publish the three RLS-protected tables exactly once",
);
console.log("Realtime publication and Vietnam timezone migration OK");
// Legacy online rows can be ambiguous even with Business currently disabled:
// a previous create request may have timed out before its URL was persisted.
const legacyUsers = [
  "44444444-4444-4444-8444-444444444444",
  "55555555-5555-4555-8555-555555555555",
];
const legacyOrders = [];
for (const user of legacyUsers) {
  await db.query("insert into auth.users(id) values($1)", [user]);
  legacyOrders.push(
    (await db.query(
      `insert into public.membership_renewal_requests(user_id,package_id,payment_method)
    values($1,(select id from public.gym_packages limit 1),'online') returning *`,
      [user],
    )).rows[0],
  );
}
// New migrations must be exercised in both bundled and sequential runs.
await db.exec(
  await readFile(
    "supabase/migrations/20261031000000_membership_payment_lifecycle.sql",
    "utf8",
  ),
);
await (await import("./payment_lifecycle.mjs")).checkLegacyMigration(
  db,
  legacyOrders,
  assert,
);
const settings =
  (await db.query("select * from public.payment_settings")).rows[0];
assert(
  settings.bank_account_holder === "Nguyễn Vũ Duy" &&
    settings.bank_account_number === "1042362758" &&
    settings.momo_phone === "0775571311",
  "Real receiving details and UTF-8 must be preserved",
);
const realPackages = (await db.query("select * from public.gym_packages")).rows;
assert(
  realPackages.length === 6,
  "Two packages are required for each of three branches",
);
assert(
  realPackages.filter((p) => p.duration_months === 1).every((p) =>
    p.price === 299000
  ),
  "Monthly price must be 299000 VND",
);
assert(
  realPackages.filter((p) => p.duration_months === 3).every((p) =>
    p.price === 299000 * 3 * 0.9
  ),
  "Quarterly price must save exactly 10 percent",
);
const uid = "11111111-1111-4111-8111-111111111111";
const other = "22222222-2222-4222-8222-222222222222";
await db.exec(`update public.payment_settings set online_enabled=true;
  insert into auth.users values('${uid}'),('${other}');
  insert into public.gym_packages(id,name,duration_days,duration_months,price,branch_name) values('33333333-3333-4333-8333-333333333333','SQL TEST ONLY',30,1,100000,'TEST ONLY');
  select set_config('request.jwt.claim.sub','${uid}',false);
  select set_config('request.jwt.claim.role','authenticated',false);
  set role authenticated;`);
const row = (await db.query(
  `insert into public.membership_renewal_requests(user_id,package_id,amount,payment_method) values($1,'33333333-3333-4333-8333-333333333333',1,'online') returning *`,
  [uid],
)).rows[0];
assert(
  row.amount === 100000 && row.duration_months === 1,
  "Price and term must be snapshotted by the backend",
);
let denied = false;
try {
  await db.query("select public.approve_membership_renewal($1)", [row.id]);
} catch {
  denied = true;
}
assert(denied, "Member must not approve their own payment");
await db.exec(`select set_config('request.jwt.claim.sub','${other}',false);`);
assert(
  (await db.query("select * from public.membership_renewal_requests")).rows
    .length === 0,
  "Other member must not read requests",
);
await db.exec(
  `reset role; select set_config('request.jwt.claim.role','service_role',false);`,
);
let mismatch = false;
try {
  await db.query("select public.confirm_online_membership($1,1,$2)", [
    row.id,
    "123456",
  ]);
} catch {
  mismatch = true;
}
assert(mismatch, "Wrong paid amount must be rejected");
await db.query("select public.confirm_online_membership($1,100000,$2)", [
  row.id,
  "123456",
]);
await db.query("select public.confirm_online_membership($1,100000,$2)", [
  row.id,
  "123456",
]);
assert(
  (await db.query("select * from public.memberships where user_id=$1", [uid]))
    .rows.length === 1,
  "Duplicate IPN must not create another membership",
);
assert(
  (await db.query("select * from public.app_notifications where user_id=$1", [
    uid,
  ])).rows.length === 1,
  "Duplicate IPN must not create another notice",
);
const contract =
  (await db.query("select * from public.memberships where user_id=$1", [uid]))
    .rows[0];
const status = (await db.query(
  "select * from public.membership_renewal_requests where id=$1",
  [row.id],
)).rows[0];
assert(
  status.status === "approved" && status.transaction_no === "123456",
  "Payment must finalize atomically",
);
assert(contract.price === 100000, "Contract must use the quoted price");
await db.exec(
  `reset role;
  select set_config('request.jwt.claim.sub','${uid}',false);
  select set_config('request.jwt.claim.role','authenticated',false);
  set role authenticated;`,
);
const firstWorkout = await db.query(
  `select public.sync_workout_session($1,$2,$3,$4,$5,$6::jsonb) as id`,
  [
    "session-sync-test",
    "Thứ Hai",
    "2026-11-02T10:00:00Z",
    "FitPlan Center",
    "2026-11-02T10:00:00Z",
    JSON.stringify([{
      exercise_name: "Bench Press",
      sets: 4,
      reps: 8,
      weight_kg: 60,
      rpe: 7,
      is_personal_record: false,
    }]),
  ],
);
const remoteSessionId = firstWorkout.rows[0].id;
const replacementWorkout = await db.query(
  `select public.sync_workout_session($1,$2,$3,$4,$5,$6::jsonb) as id`,
  [
    "session-sync-test",
    "Thứ Hai",
    "2026-11-02T10:00:00Z",
    "FitPlan Center",
    "2026-11-02T10:00:00Z",
    JSON.stringify([{
      exercise_name: "Squat",
      sets: 3,
      reps: 10,
      weight_kg: 40,
      rpe: 8,
      is_personal_record: true,
    }]),
  ],
);
assert(
  replacementWorkout.rows[0].id === remoteSessionId &&
    (await db.query(
      "select exercise_name from public.exercise_logs where session_id=$1",
      [remoteSessionId],
    )).rows.map((entry) => entry.exercise_name).join() === "Squat",
  "Workout resync must atomically replace logs without duplicating the session",
);
let invalidWorkoutRejected = false;
try {
  await db.query(
    `select public.sync_workout_session($1,$2,$3,$4,$5,$6::jsonb)`,
    [
      "session-sync-test",
      "Thứ Hai",
      "2026-11-02T10:00:00Z",
      "FitPlan Center",
      "2026-11-02T10:00:00Z",
      JSON.stringify([{
        exercise_name: "Invalid",
        sets: 0,
        reps: 10,
        weight_kg: 40,
        rpe: 8,
        is_personal_record: false,
      }]),
    ],
  );
} catch {
  invalidWorkoutRejected = true;
}
assert(
  invalidWorkoutRejected &&
    (await db.query(
      "select exercise_name from public.exercise_logs where session_id=$1",
      [remoteSessionId],
    )).rows.map((entry) => entry.exercise_name).join() === "Squat",
  "A failed workout replacement must leave the previous logs intact",
);
await db.query(
  `insert into public.profiles(user_id,name,age,height_cm,weight_kg,gender,goal,experience_level,sessions_per_week)
  values($1,'Database Test',30,170,65,'Nam','muscle','beginner',3)`,
  [uid],
);
assert(
  (await db.query(
    "select workout_minutes from public.profiles where user_id=$1",
    [uid],
  )).rows[0].workout_minutes === 60,
  "Existing and new profiles must default to a 60-minute workout",
);
await db.query(
  "update public.profiles set workout_minutes=90 where user_id=$1",
  [uid],
);
assert(
  (await db.query(
    "select workout_minutes from public.profiles where user_id=$1",
    [uid],
  )).rows[0].workout_minutes === 90,
  "Workout duration preference must persist in the profile",
);
let invalidDurationRejected = false;
try {
  await db.query(
    "update public.profiles set workout_minutes=121 where user_id=$1",
    [uid],
  );
} catch {
  invalidDurationRejected = true;
}
assert(
  invalidDurationRejected &&
    (await db.query(
      "select workout_minutes from public.profiles where user_id=$1",
      [uid],
    )).rows[0].workout_minutes === 90,
  "Invalid workout duration must not replace the saved preference",
);
console.log(
  "PASS: migrations, RLS, payment lifecycle, atomic workout sync and duration persistence.",
);
await (await import("./payment_lifecycle.mjs")).checkPaymentLifecycle(
  db,
  uid,
  other,
  assert,
);
await db.close();
