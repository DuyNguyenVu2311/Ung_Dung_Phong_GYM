# Supabase setup for FitPlan

## 1. Create and prepare the project

1. Create a project at https://supabase.com/dashboard.
2. Open **SQL Editor**.
3. Run `migrations/20261029000000_initial_schema.sql`.
4. Run `migrations/20261030000000_tracking_and_sync.sql`.
5. Run `migrations/20261030010000_app_improvements.sql`.
6. Run `APPLY_UPGRADE.sql` once (bundles migrations 020000–040000). Do not also apply those three files separately.
7. Run `migrations/20261030050000_live_payment_updates.sql`.
8. In **Authentication > Providers**, enable Email. Keep email confirmation enabled for real accounts and allow `fitplan://login-callback/` in Redirect URLs for mobile.

All personal tables use Row Level Security. A signed-in user can only access rows whose `user_id` matches their account.

## 2. Run Flutter with Supabase

Copy the Project URL and Publishable key from **Project Settings > API**, then run:

```powershell
flutter run -d chrome `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY
```

The publishable/anon key is intended for the client. Never put the `service_role` key in Flutter or commit it to source control.

The app includes the project's public URL and publishable client key as defaults. The `dart-define` values override them for another project. No service-role or merchant secrets belong in Flutter.

## 3. Test the synchronization

1. Register a new account in the app.
   Complete the required personal profile after confirming email. New accounts have no sample workout or membership.
2. Complete the daily check-in.
3. Favorite an exercise.
4. Complete a workout and choose an RPE value.
5. Add a weight measurement.
6. Open **Cá nhân**, scroll to **Đồng bộ Supabase**, and tap **Đồng bộ ngay**.
7. Check the rows in Supabase Table Editor.

FitPlan keeps a local copy in `SharedPreferences` and pushes it to Supabase after important changes. This gives the app a usable offline-first fallback.
