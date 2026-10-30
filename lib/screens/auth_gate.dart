import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_localization.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import '../services/cloud_sync_service.dart';
import 'auth_screen.dart';
import 'main_app_shell.dart';
import 'onboarding_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _subscription;
  String? _userId;
  bool _loading = false, _complete = false;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    if (!SupabaseService.isConfigured) return;
    _subscription = SupabaseService.client!.auth.onAuthStateChange.listen(
      (event) => _load(event.session?.user.id),
    );
    _load(SupabaseService.currentUser?.id);
  }

  Future<void> _load(String? id) async {
    if (id == _userId && (_loading || _complete)) return;
    final generation = ++_generation;
    setState(() {
      _userId = id;
      _loading = id != null;
      _error = null;
      _complete = false;
    });
    if (id == null) return;
    try {
      await StorageService.instance.bindUser(id);
      final row = await SupabaseService.client!
          .from('profiles')
          .select()
          .eq('user_id', id)
          .maybeSingle();
      final complete = row?['profile_completed'] == true;
      if (complete) {
        final restored = await CloudSyncService.instance.restoreOrUpload();
        if (!restored) {
          throw StateError(
            CloudSyncService.instance.lastError ?? 'Không tải được hồ sơ',
          );
        }
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _complete = complete;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppSettingsScope.watch(context);
    if (!SupabaseService.isConfigured) return MainAppShell();
    if (_userId == null) return AuthScreen();
    if (_loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LocalizedText('Không tải được hồ sơ.\n$_error'),
                FilledButton(
                  onPressed: () => _load(_userId),
                  child: LocalizedText('Thử lại'),
                ),
                TextButton(
                  onPressed: SupabaseService.signOut,
                  child: LocalizedText('Đăng xuất'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!_complete) return OnboardingScreen(onCompleted: () => _load(_userId));
    return MainAppShell(key: ValueKey(_userId));
  }
}
