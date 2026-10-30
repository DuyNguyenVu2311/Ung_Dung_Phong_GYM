import '../models/data_models.dart';

class PersonalGuidance {
  final String trainingSummary;
  final List<String> weeklyActions;
  final List<String> recoveryActions;
  final List<String> nutritionActions;

  const PersonalGuidance({
    required this.trainingSummary,
    required this.weeklyActions,
    required this.recoveryActions,
    required this.nutritionActions,
  });
}

class GuidanceService {
  GuidanceService._();

  static const physicalActivitySource =
      'https://www.who.int/europe/news-room/fact-sheets/item/physical-activity';
  static const healthyDietSource =
      'https://www.who.int/news-room/fact-sheets/detail/healthy-diet';

  static PersonalGuidance forProfile(
    UserProfile profile, {
    DailyCheckIn? checkIn,
  }) {
    final workImpact = switch (profile.activityLevel) {
      'sedentary' =>
        'Bạn ngồi nhiều trong ngày, nên thêm các quãng đi bộ ngắn.',
      'active' => 'Công việc đã vận động nhiều, cần ưu tiên hồi phục giữa các buổi sức mạnh.',
      _ =>
        'Mức vận động hằng ngày ở mức vừa, có thể duy trì lịch tập cân bằng.',
    };
    final goalText = switch (profile.goal) {
      'fatloss' => 'giảm mỡ nhưng vẫn duy trì sức mạnh',
      'maintenance' => 'duy trì thể lực và sức khỏe',
      _ => 'tăng cơ và sức mạnh',
    };
    final readiness = checkIn == null
        ? 'Hãy check-in mỗi ngày để điều chỉnh cường độ.'
        : checkIn.trainingDecision;

    return PersonalGuidance(
      trainingSummary: 'Kế hoạch hướng đến $goalText. $workImpact $readiness',
      weeklyActions: [
        '${profile.sessionsPerWeek} buổi sức mạnh/tuần, ưu tiên các ngày ${_days(profile.availableWeekdays)}.',
        'Tích lũy 150-300 phút vận động aerobic cường độ vừa mỗi tuần, hoặc lượng vận động mạnh tương đương.',
        'Tập sức mạnh các nhóm cơ lớn ít nhất 2 ngày/tuần và tăng khối lượng từ từ.',
      ],
      recoveryActions: [
        'Xen kẽ ngày tập nặng với ngày nghỉ hoặc vận động nhẹ.',
        'Nếu đau bất thường, kiệt sức hoặc ngủ rất kém: nghỉ tập và cân nhắc hỏi chuyên gia y tế.',
        'Ưu tiên ngủ đủ, uống nước và không cố hoàn thành bài tập khi kỹ thuật giảm.',
      ],
      nutritionActions: [
        'Ăn đa dạng ngũ cốc nguyên hạt, rau, trái cây, đậu, hạt và nguồn đạm phù hợp.',
        'Hướng tới ít nhất 400 g rau và trái cây mỗi ngày.',
        'Hạn chế đường tự do dưới 10% tổng năng lượng và muối dưới 5 g/ngày.',
        _dietPreference(profile.dietaryPreference),
      ],
    );
  }

  static String _days(List<int> days) {
    const names = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    if (days.isEmpty) return 'bạn sắp xếp được';
    return days
        .where((day) => day >= 1 && day <= 7)
        .map((day) => names[day - 1])
        .join(', ');
  }

  static String _dietPreference(String value) => switch (value) {
    'vegetarian' => 'Bạn ăn chay: phối hợp đậu, đậu phụ, hạt, trứng/sữa nếu phù hợp để đa dạng nguồn đạm.',
    'low_carb' => 'Nếu giảm tinh bột, vẫn ưu tiên nguồn tinh bột nguyên hạt quanh buổi tập và không loại bỏ rau quả.',
    _ => 'Với chế độ cân bằng, chia khẩu phần hợp lý và ưu tiên thực phẩm ít chế biến.',
  };
}
