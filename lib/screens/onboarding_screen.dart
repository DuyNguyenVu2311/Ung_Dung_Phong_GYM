import 'package:flutter/material.dart';

import '../services/app_localization.dart';
import '../models/data_models.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../repositories/workout_plan_repository.dart';
import '../repositories/workout_schedule_repository.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onCompleted;
  const OnboardingScreen({super.key, required this.onCompleted});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _age = TextEditingController(),
      _height = TextEditingController(),
      _weight = TextEditingController(),
      _occupation = TextEditingController(),
      _health = TextEditingController();
  String _gender = 'Nam',
      _goal = 'muscle',
      _level = 'beginner',
      _activity = 'moderate';
  final Set<int> _days = {1, 3, 5};
  bool _saving = false;
  String _time = 'evening', _diet = 'balanced';
  @override
  void dispose() {
    for (final controller in [
      _name,
      _age,
      _height,
      _weight,
      _occupation,
      _health,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _number(String text) => double.tryParse(text.replaceAll(',', '.'));
  Future<void> _save() async {
    if (!_form.currentState!.validate() || _days.isEmpty) return;
    setState(() => _saving = true);
    final profile = UserProfile(
      name: _name.text.trim(),
      age: _number(_age.text)!.toInt(),
      height: _number(_height.text)!,
      weight: _number(_weight.text)!,
      gender: _gender,
      goal: _goal,
      experienceLevel: _level,
      sessionsPerWeek: _days.length,
      occupation: _occupation.text.trim(),
      activityLevel: _activity,
      availableWeekdays: _days.toList()..sort(),
      healthNotes: _health.text.trim(),
      preferredWorkoutTime: _time,
      dietaryPreference: _diet,
    );
    try {
      await SupabaseService.client!.from('profiles').upsert({
        'user_id': SupabaseService.currentUser!.id,
        'name': profile.name,
        'age': profile.age,
        'height_cm': profile.height,
        'weight_kg': profile.weight,
        'gender': profile.gender,
        'goal': profile.goal,
        'experience_level': profile.experienceLevel,
        'sessions_per_week': profile.sessionsPerWeek,
        'occupation': profile.occupation,
        'activity_level': profile.activityLevel,
        'available_weekdays': profile.availableWeekdays,
        'health_notes': profile.healthNotes,
        'preferred_workout_time': profile.preferredWorkoutTime,
        'dietary_preference': profile.dietaryPreference,
        'profile_completed': true,
      }, onConflict: 'user_id');
      await StorageService.instance.saveProfile(profile);
      await StorageService.instance.saveGoal(profile.goal);
      await StorageService.instance.saveLevel(profile.experienceLevel);
      await StorageService.instance.saveSessionsPerWeek(
        profile.sessionsPerWeek,
      );
      await WorkoutScheduleRepository.generateSchedule(
        WorkoutPlanRepository.generatePlan(
          _goal,
          _level,
          _days.length,
          availableWeekdays: profile.availableWeekdays,
          profile: profile,
        ),
      );
      if (mounted) widget.onCompleted();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: LocalizedText('Không lưu được hồ sơ: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    double? min,
    double? max,
    bool integer = false,
    bool required = true,
  }) => Padding(
    padding: EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: tr(label)),
      keyboardType: min == null
          ? TextInputType.text
          : TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return 'Vui lòng nhập $label';
        }
        if (min != null) {
          final number = _number(value ?? '');
          if (number == null ||
              !number.isFinite ||
              number < min ||
              number > max! ||
              (integer && number != number.roundToDouble())) {
            return 'Nhập giá trị từ $min đến $max';
          }
        }
        return null;
      },
    ),
  );
  Widget _select(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> onChanged,
  ) => Padding(
    padding: EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: tr(label)),
      items: options.entries
          .map(
            (e) =>
                DropdownMenuItem(value: e.key, child: LocalizedText(e.value)),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) setState(() => onChanged(value));
      },
    ),
  );
  @override
  Widget build(BuildContext context) {
    AppSettingsScope.watch(context);
    final height = _number(_height.text) ?? 0,
        weight = _number(_weight.text) ?? 0;
    final bmi = height > 0 && weight > 0
        ? weight / ((height / 100) * (height / 100))
        : null;
    return Scaffold(
      appBar: AppBar(
        title: LocalizedText('Thiết lập hồ sơ của bạn'),
        actions: [
          IconButton(
            onPressed: SupabaseService.signOut,
            icon: Icon(Icons.logout),
            tooltip: tr('Đăng xuất'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 640),
          child: Form(
            key: _form,
            child: ListView(
              padding: EdgeInsets.all(24),
              children: [
                LocalizedText(
                  'Nhập thông tin thật để tính BMI và tạo lịch tập phù hợp.',
                ),
                SizedBox(height: 24),
                _field('Họ và tên', _name),
                _field('Tuổi', _age, min: 18, max: 100, integer: true),
                _field('Chiều cao (cm)', _height, min: 100, max: 250),
                _field('Cân nặng (kg)', _weight, min: 20, max: 400),
                if (bmi != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: LocalizedText(
                      'BMI: ${bmi.toStringAsFixed(1)}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                if (bmi != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: LocalizedText(
                      bmi < 18.5
                          ? 'Gầy'
                          : bmi < 25
                          ? 'Bình thường'
                          : bmi < 30
                          ? 'Thừa cân'
                          : 'Béo phì',
                    ),
                  ),
                _select('Giới tính', _gender, {
                  'Nam': 'Nam',
                  'Nữ': 'Nữ',
                  'Khác': 'Khác',
                }, (v) => _gender = v),
                _field('Nghề nghiệp', _occupation),
                _select('Mức vận động hằng ngày', _activity, {
                  'sedentary': 'Ngồi nhiều',
                  'moderate': 'Vận động vừa',
                  'active': 'Vận động nhiều',
                }, (v) => _activity = v),
                _select('Mục tiêu', _goal, {
                  'muscle': 'Tăng cơ',
                  'fatloss': 'Giảm mỡ',
                  'maintenance': 'Duy trì sức khỏe',
                }, (v) => _goal = v),
                _select('Kinh nghiệm tập', _level, {
                  'beginner': 'Mới bắt đầu',
                  'intermediate': 'Đã có kinh nghiệm',
                }, (v) => _level = v),
                _select('Khung giờ tập phù hợp', _time, {
                  'morning': 'Buổi sáng',
                  'afternoon': 'Buổi chiều',
                  'evening': 'Buổi tối',
                }, (v) => _time = v),
                _select('Chế độ ăn', _diet, {
                  'balanced': 'Cân bằng',
                  'vegetarian': 'Ăn chay',
                  'low_carb': 'Giảm tinh bột',
                }, (v) => _diet = v),
                LocalizedText('Chọn ngày có thể tập (tối đa 5 ngày)'),
                Wrap(
                  spacing: 8,
                  children: List.generate(
                    7,
                    (i) => FilterChip(
                      label: LocalizedText(i == 6 ? 'CN' : 'T${i + 2}'),
                      selected: _days.contains(i + 1),
                      onSelected: (selected) => setState(() {
                        if (selected && _days.length < 5) _days.add(i + 1);
                        if (!selected) _days.remove(i + 1);
                      }),
                    ),
                  ),
                ),
                if (_days.isEmpty) LocalizedText('Chọn ít nhất một ngày tập'),
                SizedBox(height: 16),
                _field(
                  'Thể trạng / chấn thương cần lưu ý',
                  _health,
                  required: false,
                ),
                FilledButton(
                  onPressed: _saving || _days.isEmpty ? null : _save,
                  child: LocalizedText(
                    _saving ? 'Đang lưu...' : 'Lưu hồ sơ và tạo lịch tập',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
