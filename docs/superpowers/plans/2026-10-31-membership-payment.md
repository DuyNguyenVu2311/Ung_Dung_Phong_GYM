# Thành viên 3 — implementation plan

> Execution: superpowers:executing-plans, directly in this worktree; use test-driven-development and verification-before-completion.

**Goal:** Implement CV3.1–CV3.3 from the supplied handoff.
**Architecture:** One membership cache refresh rule shared by cloud restore and MembershipScreen. Snapshot manual/Business payment provider per order. Serialize session creation in PostgreSQL and apply verified IPN/query results through a single atomic RPC.
**Stack:** Existing Flutter/Dart, Supabase PostgreSQL/Edge Functions, MoMo v2 query.
**Spec:** User-supplied HUONG_DAN_HAI_THANH_VIEN (2).md, section 7.

## Decisions

- Hide the unsupported used_sessions metric. Self-recorded workouts and daily health checks do not prove gym visits; no client counter updates.
- Successful empty membership query clears the cache; failed query retains it. Scope late responses to the account that initiated the request.
- Manual MoMo remains manual even if the gym later enables Business. Ambiguous historical online orders without a URL/transaction are quarantined as legacy_review, regardless of current settings; only verified success or service-role classification resolves them.
- Business session creation is claimed once before network IO. Retry queries first; no second create after an ambiguous timeout. A never-submitted order may be cancelled immediately. An attempted order may close only on a documented terminal gateway result, or a matching not-found query after the reconciliation deadline and grace period. Late verified success can still activate a closed order exactly once.
- Local deadline is a prompt to reconcile, not proof of failure. Unknown, maintenance, processing, malformed responses and network failures retain pending state.
- No deployment, shared database mutation, push or merge is included. Merchant sandbox end-to-end needs the project owner's credentials.

## Review focus

Account switch while fetching; expired/inactive branch cache; pending query codes; callback versus query race; forged provider/deadline fields.

## Task 1: membership cache and unsupported metric

Files: storage_service.dart, cloud_sync_service.dart, membership_screen.dart, workout_session_screen.dart; test/membership_cache_test.dart.
Interface: refreshMembership(Future<List<Map<String,dynamic>>> Function() fetch, {required String userId}) returns the selected row, retains cache on throw, ignores results for another account.
- [x] Write and run failing tests for empty/inactive results, network failure, late account response and expiry notices.
- [x] Implement one refresh rule and update both callers; require active, in-period cache before selecting workout branch. Hide unsupported count.
- [x] Run targeted Flutter tests and analyzer.

## Task 2: database lifecycle

Files: new 20261031000000_membership_payment_lifecycle.sql, scripts/database/check.mjs and payment_lifecycle.mjs.
Interfaces: claim_membership_payment(uuid) -> boolean; apply_momo_result(uuid,integer,integer,text,boolean) -> void; cancel_own_membership_request(uuid).
- [x] Add failing integration tests for immutable provider, owner permissions, one create claim, nonterminal results, expiration, missing order grace, late/repeated success, transaction mismatch and rollback.
- [x] Add migration and register it for both bundled and sequential test paths.
- [x] Run database checks.

## Task 3: gateway and Flutter recovery

Files: _shared/momo.ts, _shared/membership_payment.ts, membership-payment/index.ts, checkout_screen.dart, membership_screen.dart, localization, PAYMENTS_SETUP.md.
- [x] Write failing tests for official query signature, query identity/amount/transaction checks, timeout then query, terminal and nonterminal responses using fake HTTP transport only.
- [x] Implement authenticated owner reconciliation and controlled creation; IPN uses the same atomic result RPC. Flutter uses snapshotted provider, shows recovery controls after deadline and truthful status labels.
- [x] Run Deno tests/check, full Flutter analyze/test and database tests. Document deployment and sandbox limitation.

## Progress

- Baseline: database suite passed at 60be30f. C:\flutter is too old (Dart 3.13.3); D:\flutter has compatible Dart 3.13.4 and is used without changing pubspec.
- Review: two material findings addressed: passive realtime refresh prevents a query/write feedback loop; ambiguous legacy online orders remain reviewable instead of being inferred manual after settings are disabled. Regression tests observed failing then passing.
- Final verification: Flutter analyze --no-pub: no issues; Flutter test --no-pub: 59 passed; Deno tests: 18 passed; Deno check: passed; PGlite bundled and sequential migration suites: passed. Merchant sandbox and shared backend deployment remain for the project owner per PAYMENTS_SETUP.md.
