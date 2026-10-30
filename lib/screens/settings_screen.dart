import 'package:flutter/material.dart';

import '../services/app_localization.dart';

import '../services/app_settings_service.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_components.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: LocalizedText('Xóa tài khoản?'),
        content: LocalizedText(
          'Hành động này xóa tài khoản Supabase và dữ liệu đồng bộ. Bạn không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: LocalizedText('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: LocalizedText('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.client?.rpc('delete_own_account');
      await StorageService.instance.clearAll();
      await SupabaseService.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: LocalizedText('Không thể xóa tài khoản: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppSettingsScope.watch(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ModernAppBar(title: 'Cài đặt tài khoản'),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            LocalizedText('Giao diện', style: AppTextTheme.titleLarge),
            SizedBox(height: 10),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: AppSettingsService.themeMode,
              builder: (context, mode, _) => GlassCard(
                padding: EdgeInsets.all(8),
                borderRadius: 18,
                child: RadioGroup<ThemeMode>(
                  groupValue: mode,
                  onChanged: (value) {
                    if (value != null) {
                      AppSettingsService.setThemeMode(value);
                    }
                  },
                  child: Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.dark,
                        title: LocalizedText('Tối'),
                        secondary: Icon(Icons.dark_mode_rounded),
                      ),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.light,
                        title: LocalizedText('Sáng'),
                        secondary: Icon(Icons.light_mode_rounded),
                      ),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.system,
                        title: LocalizedText('Theo thiết bị'),
                        secondary: Icon(Icons.settings_brightness_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 24),
            LocalizedText('Ngôn ngữ', style: AppTextTheme.titleLarge),
            SizedBox(height: 10),
            ValueListenableBuilder<String>(
              valueListenable: AppSettingsService.language,
              builder: (context, language, _) => SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'vi',
                    label: LocalizedText('Tiếng Việt'),
                  ),
                  ButtonSegment(value: 'en', label: LocalizedText('English')),
                ],
                selected: {language},
                onSelectionChanged: (values) =>
                    AppSettingsService.setLanguage(values.first),
              ),
            ),
            SizedBox(height: 10),
            SizedBox(height: 30),
            OutlinedButton.icon(
              onPressed: () async {
                await SupabaseService.signOut();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              icon: Icon(Icons.logout_rounded),
              label: LocalizedText('Đăng xuất'),
            ),
            SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: _deleteAccount,
              icon: Icon(Icons.delete_forever_rounded),
              label: LocalizedText('Xóa tài khoản'),
            ),
          ],
        ),
      ),
    );
  }
}
