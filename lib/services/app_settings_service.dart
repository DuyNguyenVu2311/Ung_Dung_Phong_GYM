import 'package:flutter/material.dart';

import 'storage_service.dart';

class AppSettingsService {
  AppSettingsService._();

  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);
  static final language = ValueNotifier<String>('vi');
  static final platformAppearance = ValueNotifier<int>(0);
  static final _observer = _AppearanceObserver();
  static bool get isLight =>
      themeMode.value == ThemeMode.light ||
      (themeMode.value == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.light);

  static Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(_observer);
    themeMode.value = switch (StorageService.instance.loadThemeMode()) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    language.value = StorageService.instance.loadLanguage();
  }

  static Future<void> setThemeMode(ThemeMode value) async {
    themeMode.value = value;
    await StorageService.instance.saveThemeMode(value.name);
  }

  static Future<void> setLanguage(String value) async {
    language.value = value;
    await StorageService.instance.saveLanguage(value);
  }
}

class _AppearanceObserver extends WidgetsBindingObserver {
  @override
  void didChangePlatformBrightness() {
    AppSettingsService.platformAppearance.value++;
  }
}
