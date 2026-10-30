import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();

  static const _url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://cdbxmtodyvdmiddcccag.supabase.co',
  );
  static const _anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_9J4ReeHrgkqUlgOK9mhu8g_P-lnWdyK',
  );
  static bool _initialized = false;

  static bool get hasCredentials => _url.isNotEmpty && _anonKey.isNotEmpty;
  static bool get isConfigured => hasCredentials && _initialized;

  static SupabaseClient? get client =>
      isConfigured ? Supabase.instance.client : null;

  static User? get currentUser => client?.auth.currentUser;

  static Future<void> initialize() async {
    if (!hasCredentials) return;
    await Supabase.initialize(url: _url, publishableKey: _anonKey);
    _initialized = true;
  }

  static Future<void> signOut() async => client?.auth.signOut();
}
