import 'package:flutter/material.dart';

import '../services/app_localization.dart';

import '../theme/app_theme.dart';
import '../widgets/modern_components.dart';
import '../models/data_models.dart';
import '../services/storage_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/supabase_service.dart';
import '../services/guidance_service.dart';
import '../repositories/workout_plan_repository.dart';
import '../repositories/workout_schedule_repository.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _healthNotesCtrl = TextEditingController();

  String _gender = 'Nam';
  String _goal = 'muscle';
  String _level = 'beginner';
  int _sessions = 4;
  String _activityLevel = 'moderate';
  Set<int> _availableWeekdays = {1, 3, 5};
  String _preferredWorkoutTime = 'evening';
  String _dietaryPreference = 'balanced';
  bool _editing = false;

  String _goalLabel(String g) {
    switch (g) {
      case 'muscle':
        return 'Tăng cơ';
      case 'fatloss':
        return 'Giảm mỡ';
      default:
        return 'Duy trì thể lực';
    }
  }

  String _levelLabel(String l) {
    switch (l) {
      case 'beginner':
        return 'Mới bắt đầu';
      default:
        return 'Có kinh nghiệm';
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _occupationCtrl.dispose();
    _healthNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = StorageService.instance.loadProfile();
    final goal = p?.goal ?? StorageService.instance.loadGoal() ?? 'muscle';
    final level =
        p?.experienceLevel ?? StorageService.instance.loadLevel() ?? 'beginner';
    final sessions =
        p?.sessionsPerWeek ??
        StorageService.instance.loadSessionsPerWeek() ??
        3;
    if (!mounted) return;
    setState(() {
      if (p != null) {
        _nameCtrl.text = p.name;
        _ageCtrl.text = p.age.toString();
        _heightCtrl.text = p.height.toString();
        _weightCtrl.text = p.weight.toString();
        _gender = p.gender;
        _occupationCtrl.text = p.occupation;
        _activityLevel = p.activityLevel;
        _availableWeekdays = p.availableWeekdays.toSet();
        _preferredWorkoutTime = p.preferredWorkoutTime;
        _dietaryPreference = p.dietaryPreference;
        _healthNotesCtrl.text = p.healthNotes;
      }
      _goal = goal;
      _level = level;
      _sessions = sessions;
    });
  }

  double _bmi() {
    final h = double.tryParse(_heightCtrl.text) ?? 170;
    final w = double.tryParse(_weightCtrl.text) ?? 65;
    return w / ((h / 100) * (h / 100));
  }

  String _bmiLabel(double b) {
    if (b < 18.5) return 'Gầy';
    if (b < 25) return 'Bình thường';
    if (b < 30) return 'Thừa cân';
    return 'Béo phì';
  }

  Color _bmiColor(double b) {
    if (b < 18.5) return AppColors.warning;
    if (b < 25) return AppColors.primary;
    if (b < 30) return AppColors.warning;
    return AppColors.accent;
  }

  Future<void> _save() async {
    final age = int.tryParse(_ageCtrl.text);
    final height = double.tryParse(_heightCtrl.text.replaceAll(',', '.'));
    final weight = double.tryParse(_weightCtrl.text.replaceAll(',', '.'));
    if (_nameCtrl.text.trim().isEmpty ||
        age == null ||
        age < 18 ||
        age > 100 ||
        height == null ||
        !height.isFinite ||
        height < 100 ||
        height > 250 ||
        weight == null ||
        !weight.isFinite ||
        weight < 20 ||
        weight > 400 ||
        _availableWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText(
            'Vui lòng nhập đầy đủ và kiểm tra lại thông tin thể trạng.',
          ),
        ),
      );
      return;
    }
    final p = UserProfile(
      name: _nameCtrl.text,
      age: age,
      height: height,
      weight: weight,
      gender: _gender,
      goal: _goal,
      experienceLevel: _level,
      sessionsPerWeek: _sessions,
      occupation: _occupationCtrl.text.trim(),
      activityLevel: _activityLevel,
      availableWeekdays: _availableWeekdays.toList()..sort(),
      preferredWorkoutTime: _preferredWorkoutTime,
      dietaryPreference: _dietaryPreference,
      healthNotes: _healthNotesCtrl.text.trim(),
    );
    await StorageService.instance.saveProfile(p);
    await StorageService.instance.saveGoal(_goal);
    await StorageService.instance.saveLevel(_level);
    await StorageService.instance.saveSessionsPerWeek(_sessions);
    await WorkoutScheduleRepository.updateFutureSchedule(
      WorkoutPlanRepository.generatePlan(
        p.goal,
        p.experienceLevel,
        p.sessionsPerWeek,
        availableWeekdays: p.availableWeekdays,
        profile: p,
      ),
    );
    await CloudSyncService.instance.syncNow();
    if (!mounted || !context.mounted) return;
    setState(() => _editing = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: LocalizedText('Đã lưu hồ sơ')));
  }

  @override
  Widget build(BuildContext context) {
    AppSettingsScope.watch(context);
    final b = _bmi();
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: ModernAppBar(
        title: 'Hồ sơ cá nhân',
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: tr('Cài đặt'),
            icon: Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => SettingsScreen()),
            ),
          ),
          Container(
            margin: EdgeInsets.only(right: 12),
            child: IconButton(
              icon: Icon(
                _editing ? Icons.check_rounded : Icons.edit_rounded,
                color: AppColors.primary,
              ),
              onPressed: _editing
                  ? _save
                  : () => setState(() => _editing = true),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              gradient: AppGradients.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.5,
                                  ),
                                  blurRadius: 20,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.person_rounded,
                              color: AppColors.textInverse,
                              size: 40,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.background,
                                  width: 3,
                                ),
                              ),
                              child: Icon(
                                Icons.edit_rounded,
                                color: AppColors.textInverse,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    Center(
                      child: LocalizedText(
                        _nameCtrl.text.isEmpty ? 'Bạn' : _nameCtrl.text,
                        style: AppTextTheme.headlineLarge,
                      ),
                    ),
                    SizedBox(height: 6),
                    Center(
                      child: LocalizedText(
                        'Thành viên FitPlan',
                        style: AppTextTheme.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    SizedBox(height: 24),

                    SectionHeader(title: 'Thông tin cơ bản'),
                    SizedBox(height: 14),
                    _field(
                      label: 'Họ và tên',
                      ctrl: _nameCtrl,
                      hint: 'Nhập tên của bạn',
                      enabled: _editing,
                    ),
                    SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            label: 'Tuổi',
                            ctrl: _ageCtrl,
                            hint: 'tuổi',
                            enabled: _editing,
                            keyboard: TextInputType.number,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(child: _genderSelector(enabled: _editing)),
                      ],
                    ),
                    SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            label: 'Chiều cao (cm)',
                            ctrl: _heightCtrl,
                            hint: 'cm',
                            enabled: _editing,
                            keyboard: TextInputType.number,
                            suffix: 'cm',
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            label: 'Cân nặng (kg)',
                            ctrl: _weightCtrl,
                            hint: 'kg',
                            enabled: _editing,
                            keyboard: TextInputType.number,
                            suffix: 'kg',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),

                    SectionHeader(title: 'Chỉ số BMI'),
                    SizedBox(height: 12),
                    GlassCard(
                      padding: EdgeInsets.all(20),
                      borderRadius: 20,
                      color: AppColors.surfaceElevated,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.fitness_center_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: LocalizedText(
                                  'Chỉ số khối cơ thể',
                                  style: AppTextTheme.labelLarge.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 14),
                          Row(
                            children: [
                              LocalizedText(
                                b.toStringAsFixed(1),
                                style: AppTextTheme.displayLarge.copyWith(
                                  fontSize: 34,
                                  color: _bmiColor(b),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 10),
                              LocalizedText(
                                _bmiLabel(b),
                                style: AppTextTheme.labelLarge.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: _bmiColor(b),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          DividerLine(
                            margin: EdgeInsets.symmetric(vertical: 10),
                          ),
                          LocalizedText(
                            '18.5 - 24.9: Bình thường   >25: Thừa cân   <18.5: Gầy',
                            style: AppTextTheme.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),

                    SectionHeader(title: 'Mục tiêu & Lịch trình'),
                    SizedBox(height: 12),
                    _choiceCard(
                      'Mục tiêu',
                      _goalLabel(_goal),
                      Icons.fitness_center_rounded,
                      () => _pickGoal(),
                      enabled: _editing,
                    ),
                    SizedBox(height: 10),
                    _choiceCard(
                      'Trình độ',
                      _levelLabel(_level),
                      Icons.speed_rounded,
                      () => _pickLevel(),
                      enabled: _editing,
                    ),
                    SizedBox(height: 10),
                    _choiceCard(
                      'Số buổi tập/tuần',
                      '$_sessions buổi',
                      Icons.calendar_today_rounded,
                      () => _pickSessions(),
                      enabled: _editing,
                    ),
                    SizedBox(height: 24),
                    SectionHeader(title: 'Dữ liệu cá nhân hóa'),
                    SizedBox(height: 8),
                    LocalizedText(
                      'Các thông tin này giúp lịch tập phù hợp với công việc, thời gian rảnh và khả năng hồi phục của bạn.',
                      style: AppTextTheme.bodySmall,
                    ),
                    SizedBox(height: 14),
                    _field(
                      label: 'Công việc hoặc nghề nghiệp',
                      ctrl: _occupationCtrl,
                      hint: 'Ví dụ: nhân viên văn phòng',
                      enabled: _editing,
                    ),
                    SizedBox(height: 10),
                    _choiceCard(
                      'Mức vận động trong ngày',
                      _activityLabel(_activityLevel),
                      Icons.directions_walk_rounded,
                      _pickActivityLevel,
                      enabled: _editing,
                    ),
                    SizedBox(height: 10),
                    _choiceCard(
                      'Khung giờ tập phù hợp',
                      _timeLabel(_preferredWorkoutTime),
                      Icons.schedule_rounded,
                      _pickPreferredTime,
                      enabled: _editing,
                    ),
                    SizedBox(height: 10),
                    _choiceCard(
                      'Chế độ ăn',
                      _dietLabel(_dietaryPreference),
                      Icons.restaurant_rounded,
                      _pickDiet,
                      enabled: _editing,
                    ),
                    SizedBox(height: 14),
                    LocalizedText(
                      'Ngày có thể tập',
                      style: AppTextTheme.labelLarge,
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: List.generate(7, (index) {
                        const names = [
                          'T2',
                          'T3',
                          'T4',
                          'T5',
                          'T6',
                          'T7',
                          'CN',
                        ];
                        final day = index + 1;
                        return FilterChip(
                          selected: _availableWeekdays.contains(day),
                          label: LocalizedText(names[index]),
                          onSelected: _editing
                              ? (selected) => setState(() {
                                  selected
                                      ? _availableWeekdays.add(day)
                                      : _availableWeekdays.remove(day);
                                })
                              : null,
                        );
                      }),
                    ),
                    SizedBox(height: 14),
                    _field(
                      label: 'Lưu ý sức khỏe hoặc chấn thương',
                      ctrl: _healthNotesCtrl,
                      hint: 'Để trống nếu không có',
                      enabled: _editing,
                    ),
                    SizedBox(height: 18),
                    _guidanceCard(),
                    SizedBox(height: 20),
                    _cloudCard(),
                    SizedBox(height: 12),
                    SizedBox(height: 26),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: GradientButton(
                onPressed: _editing
                    ? _save
                    : () => setState(() => _editing = true),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LocalizedText(
                      _editing ? 'Lưu hồ sơ' : 'Chỉnh sửa',
                      style: AppTextTheme.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textInverse,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      _editing ? Icons.save_rounded : Icons.edit_rounded,
                      size: 20,
                      color: AppColors.textInverse,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cloudCard() {
    final configured = SupabaseService.isConfigured;
    final user = SupabaseService.currentUser;
    return Container(
      padding: EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: configured
              ? AppColors.primary.withValues(alpha: .35)
              : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                configured ? Icons.cloud_done_outlined : Icons.phone_android,
                color: configured ? AppColors.primary : AppColors.secondary,
              ),
              SizedBox(width: 10),
              Expanded(
                child: LocalizedText(
                  configured ? 'Đồng bộ Supabase' : 'Chế độ dữ liệu cục bộ',
                  style: AppTextTheme.titleMedium,
                ),
              ),
            ],
          ),
          SizedBox(height: 7),
          LocalizedText(
            configured ? (user?.email ?? 'Tài khoản đã đăng nhập') : 'App vẫn dùng được đầy đủ. Thêm SUPABASE_URL và SUPABASE_ANON_KEY để bật tài khoản và đồng bộ.',
            style: AppTextTheme.bodySmall,
          ),
          if (configured) ...[
            SizedBox(height: 14),
            ValueListenableBuilder<bool>(
              valueListenable: CloudSyncService.instance.syncing,
              builder: (context, syncing, _) => Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: syncing
                          ? null
                          : () async {
                              final success = await CloudSyncService.instance
                                  .syncNow();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: LocalizedText(
                                    success
                                        ? 'Đã đồng bộ dữ liệu lên Supabase'
                                        : 'Chưa thể đồng bộ. Kiểm tra migration và kết nối.',
                                  ),
                                ),
                              );
                            },
                      icon: syncing
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.sync_rounded),
                      label: LocalizedText(
                        syncing ? 'Đang đồng bộ' : 'Đồng bộ ngay',
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    tooltip: tr('Đăng xuất'),
                    onPressed: SupabaseService.signOut,
                    icon: Icon(Icons.logout_rounded),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController ctrl,
    String? hint,
    bool enabled = false,
    TextInputType? keyboard,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LocalizedText(
          label,
          style: AppTextTheme.labelLarge.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 8),
        SizedBox(
          height: 50,
          child: TextField(
            controller: ctrl,
            enabled: enabled,
            keyboardType: keyboard,
            style: TextStyle(
              fontFamily: AppTextTheme.font,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint == null ? null : tr(hint),
              hintStyle: TextStyle(
                fontFamily: AppTextTheme.font,
                fontSize: 14,
                color: AppColors.textMuted,
              ),
              suffixText: suffix,
              suffixStyle: TextStyle(
                fontFamily: AppTextTheme.font,
                fontSize: 13,
                color: AppColors.textMuted,
              ),
              filled: true,
              fillColor: enabled
                  ? AppColors.surfaceElevated
                  : AppColors.surface.withValues(alpha: 0.6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _genderSelector({required bool enabled}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LocalizedText(
          'Giới tính',
          style: TextStyle(
            fontFamily: AppTextTheme.font,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider, width: 1),
          ),
          child: SegmentedButton<String>(
            selected: {_gender},
            onSelectionChanged: enabled
                ? (s) => setState(() => _gender = s.first)
                : null,
            style: SegmentedButton.styleFrom(
              backgroundColor: AppColors.surfaceElevated,
              selectedBackgroundColor: AppColors.primary.withValues(alpha: 0.2),
            ),
            segments: [
              ButtonSegment(
                value: 'Nam',
                label: LocalizedText(
                  'Nam',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ButtonSegment(
                value: 'Nữ',
                label: LocalizedText(
                  'Nữ',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _choiceCard(
    String label,
    String value,
    IconData icon,
    VoidCallback onTap, {
    bool enabled = false,
  }) {
    return GlassCard(
      padding: EdgeInsets.all(16),
      borderRadius: 16,
      color: AppColors.surfaceElevated,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  label,
                  style: AppTextTheme.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 2),
                LocalizedText(
                  value,
                  style: AppTextTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (enabled)
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: LocalizedText(
                  'Đổi',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _pickGoal() {
    final items = {
      'muscle': 'Tăng cơ',
      'fatloss': 'Giảm mỡ',
      'maintenance': 'Duy trì thể lực',
    };
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocalizedText(
                'Chọn mục tiêu',
                style: AppTextTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 16),
              ...items.entries.map(
                (e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _goal == e.key
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.radio_button_checked,
                      color: _goal == e.key
                          ? AppColors.textInverse
                          : AppColors.textMuted,
                      size: 18,
                    ),
                  ),
                  title: LocalizedText(
                    e.value,
                    style: TextStyle(
                      fontFamily: AppTextTheme.font,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    setState(() => _goal = e.key);
                    Navigator.pop(c);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickLevel() {
    final items = {'beginner': 'Mới bắt đầu', 'exp': 'Có kinh nghiệm'};
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocalizedText(
                'Chọn trình độ',
                style: AppTextTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 16),
              ...items.entries.map(
                (e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _level == e.key
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.radio_button_checked,
                      color: _level == e.key
                          ? AppColors.textInverse
                          : AppColors.textMuted,
                      size: 18,
                    ),
                  ),
                  title: LocalizedText(
                    e.value,
                    style: TextStyle(
                      fontFamily: AppTextTheme.font,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    setState(() => _level = e.key);
                    Navigator.pop(c);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickSessions() {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocalizedText(
                'Số buổi tập/tuần',
                style: AppTextTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(5, (i) {
                  final d = i + 1;
                  final active = _sessions == d;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _sessions = d);
                      Navigator.pop(c);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: active ? AppColors.primary : AppColors.divider,
                          width: 1,
                        ),
                      ),
                      child: LocalizedText(
                        '$d buổi',
                        style: TextStyle(
                          fontFamily: AppTextTheme.font,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? AppColors.textInverse
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _activityLabel(String value) => switch (value) {
    'sedentary' => 'Ít vận động / ngồi nhiều',
    'active' => 'Vận động nhiều',
    _ => 'Vận động vừa',
  };

  String _timeLabel(String value) => switch (value) {
    'morning' => 'Buổi sáng',
    'afternoon' => 'Buổi chiều',
    _ => 'Buổi tối',
  };

  String _dietLabel(String value) => switch (value) {
    'vegetarian' => 'Ăn chay',
    'low_carb' => 'Giảm tinh bột',
    _ => 'Cân bằng',
  };

  void _pickActivityLevel() =>
      _pickOption('Mức vận động trong ngày', _activityLevel, {
        'sedentary': 'Ít vận động / ngồi nhiều',
        'moderate': 'Vận động vừa',
        'active': 'Vận động nhiều',
      }, (value) => setState(() => _activityLevel = value));

  void _pickPreferredTime() => _pickOption(
    'Khung giờ tập phù hợp',
    _preferredWorkoutTime,
    {'morning': 'Buổi sáng', 'afternoon': 'Buổi chiều', 'evening': 'Buổi tối'},
    (value) => setState(() => _preferredWorkoutTime = value),
  );

  void _pickDiet() => _pickOption('Chế độ ăn', _dietaryPreference, {
    'balanced': 'Cân bằng',
    'vegetarian': 'Ăn chay',
    'low_carb': 'Giảm tinh bột',
  }, (value) => setState(() => _dietaryPreference = value));

  Future<void> _pickOption(
    String title,
    String current,
    Map<String, String> items,
    ValueChanged<String> onChanged,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: LocalizedText(title),
        content: RadioGroup<String>(
          groupValue: current,
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
              Navigator.pop(dialogContext);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: items.entries
                .map(
                  (entry) => RadioListTile<String>(
                    value: entry.key,
                    title: LocalizedText(entry.value),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _guidanceCard() {
    final profile = UserProfile(
      name: _nameCtrl.text,
      age: int.tryParse(_ageCtrl.text) ?? 22,
      height: double.tryParse(_heightCtrl.text) ?? 170,
      weight: double.tryParse(_weightCtrl.text) ?? 65,
      gender: _gender,
      goal: _goal,
      experienceLevel: _level,
      sessionsPerWeek: _sessions,
      occupation: _occupationCtrl.text,
      activityLevel: _activityLevel,
      availableWeekdays: _availableWeekdays.toList(),
      preferredWorkoutTime: _preferredWorkoutTime,
      dietaryPreference: _dietaryPreference,
      healthNotes: _healthNotesCtrl.text,
    );
    final guidance = GuidanceService.forProfile(
      profile,
      checkIn: StorageService.instance.loadTodayCheckIn(),
    );
    return GlassCard(
      padding: EdgeInsets.all(17),
      borderRadius: 20,
      color: AppColors.surfaceElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
              SizedBox(width: 9),
              Expanded(
                child: LocalizedText(
                  'Gợi ý theo hồ sơ',
                  style: AppTextTheme.titleMedium,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          LocalizedText(
            guidance.trainingSummary,
            style: AppTextTheme.bodySmall,
          ),
          SizedBox(height: 10),
          ...guidance.weeklyActions
              .take(2)
              .map(
                (text) => Padding(
                  padding: EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: LocalizedText(
                          text,
                          style: AppTextTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          LocalizedText(
            'Nguồn hướng dẫn chung: WHO. Không thay thế chẩn đoán hoặc tư vấn y khoa.',
            style: AppTextTheme.caption,
          ),
        ],
      ),
    );
  }
}
