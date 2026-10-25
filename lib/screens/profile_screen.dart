import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_components.dart';
import '../models/data_models.dart';
import '../services/storage_service.dart';
import 'goal_screen.dart';
import 'level_screen.dart';

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

  String _gender = 'Nam';
  String _goal = 'muscle';
  String _level = 'beginner';
  int _sessions = 4;
  bool _editing = false;

  String _goalLabel(String g) {
    switch (g) {
      case 'muscle': return 'Tăng cơ';
      case 'fatloss': return 'Giảm mỡ';
      default: return 'Duy trì thể lực';
    }
  }

  String _levelLabel(String l) {
    switch (l) {
      case 'beginner': return 'Mới bắt đầu';
      default: return 'Có kinh nghiệm';
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = StorageService.instance.loadProfile();
    final goal = StorageService.instance.loadGoal() ?? 'muscle';
    final level = StorageService.instance.loadLevel() ?? 'beginner';
    final sessions = StorageService.instance.loadSessionsPerWeek() ?? 4;
    if (!mounted) return;
    setState(() {
      if (p != null) {
        _nameCtrl.text = p.name;
        _ageCtrl.text = p.age.toString();
        _heightCtrl.text = p.height.toString();
        _weightCtrl.text = p.weight.toString();
        _gender = p.gender;
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
    final p = UserProfile(
      name: _nameCtrl.text,
      age: int.tryParse(_ageCtrl.text) ?? 22,
      height: double.tryParse(_heightCtrl.text) ?? 170.0,
      weight: double.tryParse(_weightCtrl.text) ?? 65.0,
      gender: _gender,
      goal: _goal,
      experienceLevel: _level,
      sessionsPerWeek: _sessions,
    );
    await StorageService.instance.saveProfile(p);
    await StorageService.instance.saveGoal(_goal);
    await StorageService.instance.saveLevel(_level);
    await StorageService.instance.saveSessionsPerWeek(_sessions);
    if (!mounted) return;
    setState(() => _editing = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu hồ sơ')));
  }

  @override
  Widget build(BuildContext context) {
    final b = _bmi();
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: ModernAppBar(
        title: 'Hồ sơ cá nhân',
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: Icon(_editing ? Icons.check_rounded : Icons.edit_rounded, color: AppColors.primary),
              onPressed: _editing ? _save : () => setState(() => _editing = true),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                                BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 8)),
                              ],
                            ),
                            child: const Icon(Icons.person_rounded, color: AppColors.textInverse, size: 40),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: AppColors.background, width: 3)),
                              child: const Icon(Icons.edit_rounded, color: AppColors.textInverse, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        _nameCtrl.text.isEmpty ? 'Bạn' : _nameCtrl.text,
                        style: AppTextTheme.headlineLarge,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'Thành viên FitPlan',
                        style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SectionHeader(title: 'Thông tin cơ bản'),
                    const SizedBox(height: 14),
                    _field(label: 'Họ và tên', ctrl: _nameCtrl, hint: 'Nhập tên của bạn', enabled: _editing),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _field(label: 'Tuổi', ctrl: _ageCtrl, hint: 'tuổi', enabled: _editing, keyboard: TextInputType.number)),
                        const SizedBox(width: 12),
                        Expanded(child: _genderSelector(enabled: _editing)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _field(label: 'Chiều cao (cm)', ctrl: _heightCtrl, hint: 'cm', enabled: _editing, keyboard: TextInputType.number, suffix: 'cm')),
                        const SizedBox(width: 12),
                        Expanded(child: _field(label: 'Cân nặng (kg)', ctrl: _weightCtrl, hint: 'kg', enabled: _editing, keyboard: TextInputType.number, suffix: 'kg')),
                      ],
                    ),
                    const SizedBox(height: 20),

                    SectionHeader(title: 'Chỉ số BMI'),
                    const SizedBox(height: 12),
                    GlassCard(
                      padding: const EdgeInsets.all(20),
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
                                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text('Chỉ số khối cơ thể', style: AppTextTheme.labelLarge.copyWith(fontWeight: FontWeight.w700))),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Text(b.toStringAsFixed(1), style: AppTextTheme.displayLarge.copyWith(fontSize: 34, color: _bmiColor(b), fontWeight: FontWeight.w800)),
                              const SizedBox(width: 10),
                              Text(_bmiLabel(b), style: AppTextTheme.labelLarge.copyWith(fontWeight: FontWeight.w700, color: _bmiColor(b))),
                            ],
                          ),
                          const SizedBox(height: 10),
                          DividerLine(margin: const EdgeInsets.symmetric(vertical: 10)),
                          Text(
                            '18.5 - 24.9: Bình thường   >25: Thừa cân   <18.5: Gầy',
                            style: AppTextTheme.caption.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    SectionHeader(title: 'Mục tiêu & Lịch trình'),
                    const SizedBox(height: 12),
                    _choiceCard('Mục tiêu', _goalLabel(_goal), Icons.fitness_center_rounded, () => _pickGoal(), enabled: _editing),
                    const SizedBox(height: 10),
                    _choiceCard('Trình độ', _levelLabel(_level), Icons.speed_rounded, () => _pickLevel(), enabled: _editing),
                    const SizedBox(height: 10),
                    _choiceCard('Số buổi tập/tuần', '$_sessions buổi', Icons.calendar_today_rounded, () => _pickSessions(), enabled: _editing),
                    const SizedBox(height: 26),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: GradientButton(
                onPressed: _save,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_editing ? 'Lưu hồ sơ' : 'Chỉnh sửa', style: AppTextTheme.labelLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.textInverse)),
                    const SizedBox(width: 8),
                    Icon(_editing ? Icons.save_rounded : Icons.edit_rounded, size: 20, color: AppColors.textInverse),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const ModernBottomNav(currentIndex: 4, onTap: null),
    );
  }

  Widget _field({required String label, required TextEditingController ctrl, String? hint, bool enabled = false, TextInputType? keyboard, String? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextTheme.labelLarge.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        SizedBox(
          height: 50,
          child: TextField(
            controller: ctrl,
            enabled: enabled,
            keyboardType: keyboard,
            style: const TextStyle(fontFamily: AppTextTheme.font, fontSize: 15, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontFamily: AppTextTheme.font, fontSize: 14, color: AppColors.textMuted),
              suffixText: suffix,
              suffixStyle: const TextStyle(fontFamily: AppTextTheme.font, fontSize: 13, color: AppColors.textMuted),
              filled: true,
              fillColor: enabled ? AppColors.surfaceElevated : AppColors.surface.withOpacity(0.6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        const Text('Giới tính', style: TextStyle(fontFamily: AppTextTheme.font, fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider, width: 1)),
          child: SegmentedButton<String>(
            selected: {_gender},
            onSelectionChanged: enabled ? (s) => setState(() => _gender = s.first) : null,
            style: SegmentedButton.styleFrom(
              backgroundColor: AppColors.surfaceElevated,
              selectedBackgroundColor: AppColors.primary.withOpacity(0.2),
            ),
            segments: const [
              ButtonSegment(value: 'Nam', label: Text('Nam', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
              ButtonSegment(value: 'Nữ', label: Text('Nữ', style: TextStyle(color: AppColors.textPrimary))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _choiceCard(String label, String value, IconData icon, VoidCallback onTap, {bool enabled = false}) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      color: AppColors.surfaceElevated,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: AppTextTheme.titleMedium.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (enabled)
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: const Text('Đổi', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  void _pickGoal() {
    final items = {'muscle': 'Tăng cơ', 'fatloss': 'Giảm mỡ', 'maintenance': 'Duy trì thể lực'};
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chọn mục tiêu', style: AppTextTheme.titleMedium.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ...items.entries.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(color: _goal == e.key ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.radio_button_checked, color: _goal == e.key ? AppColors.textInverse : AppColors.textMuted, size: 18),
                    ),
                    title: Text(e.value, style: const TextStyle(fontFamily: AppTextTheme.font, fontSize: 15, color: AppColors.textPrimary)),
                    onTap: () {
                      setState(() => _goal = e.key);
                      Navigator.pop(c);
                    },
                  )),
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
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chọn trình độ', style: AppTextTheme.titleMedium.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ...items.entries.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(color: _level == e.key ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.radio_button_checked, color: _level == e.key ? AppColors.textInverse : AppColors.textMuted, size: 18),
                    ),
                    title: Text(e.value, style: const TextStyle(fontFamily: AppTextTheme.font, fontSize: 15, color: AppColors.textPrimary)),
                    onTap: () {
                      setState(() => _level = e.key);
                      Navigator.pop(c);
                    },
                  )),
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
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Số buổi tập/tuần', style: AppTextTheme.titleMedium.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: active ? AppColors.primary : AppColors.divider, width: 1),
                      ),
                      child: Text('$d buổi', style: TextStyle(fontFamily: AppTextTheme.font, fontSize: 14, fontWeight: FontWeight.w600, color: active ? AppColors.textInverse : AppColors.textSecondary)),
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
}
