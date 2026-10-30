import 'dart:convert';

import '../services/app_clock.dart';

class UserProfile {
  final String name;
  final int age;
  final double height;
  final double weight;
  final String gender;
  final String goal;
  final String experienceLevel;
  final int sessionsPerWeek;
  final String occupation;
  final String activityLevel;
  final List<int> availableWeekdays;
  final String preferredWorkoutTime;
  final String dietaryPreference;
  final String healthNotes;

  UserProfile({
    required this.name,
    required this.age,
    required this.height,
    required this.weight,
    required this.gender,
    required this.goal,
    required this.experienceLevel,
    required this.sessionsPerWeek,
    this.occupation = '',
    this.activityLevel = 'moderate',
    this.availableWeekdays = const [1, 3, 5],
    this.preferredWorkoutTime = 'evening',
    this.dietaryPreference = 'balanced',
    this.healthNotes = '',
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'age': age,
    'height': height,
    'weight': weight,
    'gender': gender,
    'goal': goal,
    'experienceLevel': experienceLevel,
    'sessionsPerWeek': sessionsPerWeek,
    'occupation': occupation,
    'activityLevel': activityLevel,
    'availableWeekdays': availableWeekdays,
    'preferredWorkoutTime': preferredWorkoutTime,
    'dietaryPreference': dietaryPreference,
    'healthNotes': healthNotes,
  };

  String toJsonString() => jsonEncode(toJson());

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] ?? '',
    age: json['age'] ?? 22,
    height: json['height'] ?? 170.0,
    weight: json['weight'] ?? 65.0,
    gender: json['gender'] ?? 'Nam',
    goal: json['goal'] ?? 'muscle',
    experienceLevel: json['experienceLevel'] ?? 'exp',
    sessionsPerWeek: json['sessionsPerWeek'] ?? 4,
    occupation: json['occupation'] ?? '',
    activityLevel: json['activityLevel'] ?? 'moderate',
    availableWeekdays: List<int>.from(
      json['availableWeekdays'] as List? ?? const [1, 3, 5],
    ),
    preferredWorkoutTime: json['preferredWorkoutTime'] ?? 'evening',
    dietaryPreference: json['dietaryPreference'] ?? 'balanced',
    healthNotes: json['healthNotes'] ?? '',
  );

  factory UserProfile.fromJsonString(String s) =>
      UserProfile.fromJson(jsonDecode(s) as Map<String, dynamic>);

  double get bmi {
    final h = height / 100;
    return weight / (h * h);
  }

  String get bmiLabel {
    final b = bmi;
    if (b < 18.5) return 'Gầy';
    if (b < 25) return 'Bình thường';
    if (b < 30) return 'Thừa cân';
    return 'Béo phì';
  }
}

class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final String description;
  final String imageUrl;
  final String equipment;
  final String difficulty;
  final int durationMinutes;
  final List<String> instructions;
  final String safetyTip;

  Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.description,
    required this.imageUrl,
    this.equipment = 'Bodyweight',
    this.difficulty = 'Dễ',
    this.durationMinutes = 12,
    this.instructions = const [],
    this.safetyTip = 'Giữ nhịp thở đều và dừng lại nếu cảm thấy đau.',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'muscleGroup': muscleGroup,
    'description': description,
    'imageUrl': imageUrl,
    'equipment': equipment,
    'difficulty': difficulty,
    'durationMinutes': durationMinutes,
    'instructions': instructions,
    'safetyTip': safetyTip,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    muscleGroup: json['muscleGroup'] ?? '',
    description: json['description'] ?? '',
    imageUrl: json['imageUrl'] ?? '',
    equipment: json['equipment'] ?? 'Bodyweight',
    difficulty: json['difficulty'] ?? 'Dễ',
    durationMinutes: json['durationMinutes'] ?? 12,
    instructions: List<String>.from(json['instructions'] as List? ?? []),
    safetyTip:
        json['safetyTip'] ?? 'Giữ nhịp thở đều và dừng lại nếu cảm thấy đau.',
  );
}

class WorkoutDay {
  final String id;
  final String dayName;
  final List<WorkoutPlanExercise> exercises;

  WorkoutDay({
    required this.id,
    required this.dayName,
    required this.exercises,
  });
}

class WorkoutPlanExercise {
  final String id;
  final String workoutDayId;
  final String exerciseId;
  final int sets;
  final int reps;
  final double weight;

  WorkoutPlanExercise({
    required this.id,
    required this.workoutDayId,
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.weight,
  });
}

class WorkoutSession {
  final String id;
  final String dayName;
  final DateTime date;
  final List<ExerciseLog> logs;
  final String branchName;
  final DateTime? checkedInAt;

  WorkoutSession({
    required this.id,
    required this.dayName,
    required this.date,
    required this.logs,
    this.branchName = 'FitPlan Center',
    this.checkedInAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'dayName': dayName,
    'date': date.toIso8601String(),
    'logs': logs.map((l) => l.toJson()).toList(),
    'branchName': branchName,
    'checkedInAt': checkedInAt?.toIso8601String(),
  };

  String toJsonString() => jsonEncode(toJson());

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
    id: json['id'] ?? '',
    dayName: json['dayName'] ?? '',
    date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
    logs: (json['logs'] as List? ?? [])
        .map((l) => ExerciseLog.fromJson(l))
        .toList(),
    branchName: json['branchName'] ?? 'FitPlan Center',
    checkedInAt: json['checkedInAt'] == null
        ? null
        : DateTime.tryParse(json['checkedInAt'] as String),
  );

  factory WorkoutSession.fromJsonString(String s) =>
      WorkoutSession.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

class ExerciseLog {
  final String id;
  final String sessionId;
  final String exerciseName;
  final int sets;
  final int reps;
  final double weight;
  final int rpe;
  final bool isPersonalRecord;

  ExerciseLog({
    required this.id,
    required this.sessionId,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    required this.weight,
    this.rpe = 7,
    this.isPersonalRecord = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'exerciseName': exerciseName,
    'sets': sets,
    'reps': reps,
    'weight': weight,
    'rpe': rpe,
    'isPersonalRecord': isPersonalRecord,
  };

  factory ExerciseLog.fromJson(Map<String, dynamic> json) => ExerciseLog(
    id: json['id'] ?? '',
    sessionId: json['sessionId'] ?? '',
    exerciseName: json['exerciseName'] ?? '',
    sets: json['sets'] ?? 0,
    reps: json['reps'] ?? 0,
    weight: json['weight'] ?? 0.0,
    rpe: (json['rpe'] as num?)?.toInt() ?? 7,
    isPersonalRecord: json['isPersonalRecord'] as bool? ?? false,
  );
}

class DailyCheckIn {
  final DateTime date;
  final int energy;
  final int soreness;
  final int sleepQuality;
  final int availableMinutes;

  const DailyCheckIn({
    required this.date,
    required this.energy,
    required this.soreness,
    required this.sleepQuality,
    required this.availableMinutes,
  });

  int get readinessScore {
    final raw = (energy - 1) * 9 + (sleepQuality - 1) * 8 + (5 - soreness) * 7;
    return (raw * 100 / 96).round().clamp(0, 100).toInt();
  }

  bool get shouldRest =>
      energy <= 1 || soreness >= 5 || sleepQuality <= 1 || readinessScore < 40;
  bool get recoveryOnly =>
      !shouldRest && (readinessScore < 60 || soreness >= 4);

  String get recommendation {
    if (shouldRest) return 'Nên nghỉ tập và ưu tiên hồi phục';
    if (recoveryOnly) return 'Ưu tiên phục hồi nhẹ';
    if (readinessScore >= 75) return 'Sẵn sàng tăng tốc';
    if (readinessScore >= 50) return 'Duy trì cường độ vừa';
    return 'Ưu tiên phục hồi nhẹ';
  }

  String get trainingDecision {
    if (shouldRest) {
      return 'Nên nghỉ tập và ưu tiên hồi phục';
    }
    if (recoveryOnly) {
      return 'Tập phục hồi nhẹ, không tập đến kiệt sức';
    }
    if (readinessScore < 75) {
      return 'Có thể tập với cường độ vừa';
    }
    return 'Sẵn sàng cho buổi tập theo kế hoạch';
  }

  int get suggestedMinutes {
    if (shouldRest) return 0;
    if (recoveryOnly) {
      return availableMinutes.clamp(20, 45).toInt();
    }
    return availableMinutes.clamp(45, 90).toInt();
  }

  String get energyLabel => const [
    'Kiệt sức',
    'Mệt',
    'Bình thường',
    'Khỏe',
    'Rất sung sức',
  ][energy - 1];

  String get sorenessLabel => const [
    'Không đau',
    'Hơi căng',
    'Đau nhẹ',
    'Đau nhiều',
    'Đau bất thường',
  ][soreness - 1];

  String get sleepLabel => const [
    'Rất kém',
    'Kém',
    'Tạm ổn',
    'Ngủ tốt',
    'Ngủ rất tốt',
  ][sleepQuality - 1];

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'energy': energy,
    'soreness': soreness,
    'sleepQuality': sleepQuality,
    'availableMinutes': availableMinutes,
  };

  factory DailyCheckIn.fromJson(Map<String, dynamic> json) => DailyCheckIn(
    date: DateTime.parse(json['date'] as String),
    energy: (json['energy'] as num).toInt(),
    soreness: (json['soreness'] as num).toInt(),
    sleepQuality: (json['sleepQuality'] as num).toInt(),
    availableMinutes: (json['availableMinutes'] as num).toInt(),
  );
}

class BodyMeasurement {
  final String id;
  final DateTime date;
  final double weight;

  const BodyMeasurement({
    required this.id,
    required this.date,
    required this.weight,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'weight': weight,
  };

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) =>
      BodyMeasurement(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        weight: (json['weight'] as num).toDouble(),
      );
}

class MembershipPlan {
  final String id;
  final String name;
  final String branchName;
  final DateTime startDate;
  final DateTime endDate;
  final int usedSessions;
  final int totalSessions;
  final int price;
  final bool active;

  const MembershipPlan({
    required this.id,
    required this.name,
    required this.branchName,
    required this.startDate,
    required this.endDate,
    required this.usedSessions,
    required this.totalSessions,
    required this.price,
    this.active = true,
  });

  int get remainingDays {
    final today = AppClock.now();
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final start = DateTime(today.year, today.month, today.day);
    return end.difference(start).inDays.clamp(0, 9999).toInt();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'branchName': branchName,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'usedSessions': usedSessions,
    'totalSessions': totalSessions,
    'price': price,
    'active': active,
  };

  factory MembershipPlan.fromJson(Map<String, dynamic> json) => MembershipPlan(
    id: json['id'] as String,
    name: json['name'] as String,
    branchName: json['branchName'] as String,
    startDate: DateTime.parse(json['startDate'] as String),
    endDate: DateTime.parse(json['endDate'] as String),
    usedSessions: (json['usedSessions'] as num).toInt(),
    totalSessions: (json['totalSessions'] as num).toInt(),
    price: (json['price'] as num).toInt(),
    active: json['active'] as bool? ?? true,
  );
}

class AppNotice {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final String type;
  final bool read;

  const AppNotice({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.type,
    this.read = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'createdAt': createdAt.toIso8601String(),
    'type': type,
    'read': read,
  };

  factory AppNotice.fromJson(Map<String, dynamic> json) => AppNotice(
    id: json['id'] as String,
    title: json['title'] as String,
    message: json['message'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    type: json['type'] as String? ?? 'system',
    read: json['read'] as bool? ?? false,
  );
}

class PlanExercise {
  final Exercise exercise;
  final int sets;
  final int reps;
  final double weight;

  PlanExercise({
    required this.exercise,
    required this.sets,
    required this.reps,
    required this.weight,
  });
}

class PlanDay {
  final String dayName;
  final bool isRest;
  final List<PlanExercise> exercises;

  PlanDay({
    required this.dayName,
    required this.isRest,
    required this.exercises,
  });
}

Exercise _withExerciseMetadata(Exercise exercise) {
  final lowerName = exercise.name.toLowerCase();
  final equipment = lowerName.contains('dumbbell') || lowerName.contains('curl')
      ? 'Tạ đơn'
      : lowerName.contains('cable') ||
            lowerName.contains('pulldown') ||
            lowerName.contains('extension') ||
            lowerName.contains('leg press')
      ? 'Máy tập'
      : lowerName.contains('barbell') ||
            lowerName.contains('bench press') ||
            lowerName.contains('deadlift') ||
            lowerName.contains('squat')
      ? 'Tạ đòn'
      : 'Bodyweight';
  final difficulty =
      lowerName.contains('deadlift') ||
          lowerName.contains('squat') ||
          lowerName.contains('pull-up')
      ? 'Nâng cao'
      : equipment == 'Bodyweight'
      ? 'Dễ'
      : 'Vừa';

  return Exercise(
    id: exercise.id,
    name: exercise.name,
    muscleGroup: exercise.muscleGroup,
    description: exercise.description,
    imageUrl: exercise.imageUrl,
    equipment: equipment,
    difficulty: difficulty,
    durationMinutes: difficulty == 'Dễ' ? 8 : 12,
    instructions: [
      'Chuẩn bị tư thế vững, siết cơ bụng và giữ lưng trung lập.',
      'Thực hiện động tác có kiểm soát, thở ra ở pha dùng lực.',
      'Trở về vị trí ban đầu chậm rãi và lặp lại đúng kỹ thuật.',
    ],
    safetyTip: 'Ưu tiên biên độ đúng kỹ thuật; giảm mức tạ nếu tư thế bị lệch.',
  );
}

final List<Exercise> defaultExercises = <Exercise>[
  Exercise(
    id: 'ex001',
    name: 'Bench Press',
    muscleGroup: 'Ngực',
    description: 'Đẩy ngực ngang với thanh tạ đòn',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex002',
    name: 'Incline Dumbbell Press',
    muscleGroup: 'Ngực',
    description: 'Đẩy tạ đơn nghiêng',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex003',
    name: 'Cable Chest Flyes',
    muscleGroup: 'Ngực',
    description: 'Kéo cáp vuông góc ngực',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex004',
    name: 'Push-up',
    muscleGroup: 'Ngực',
    description: 'Hít đất',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex005',
    name: 'Chest Dips',
    muscleGroup: 'Ngực',
    description: 'Xà kép',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex006',
    name: 'Lat Pulldown',
    muscleGroup: 'Lưng',
    description: 'Kéo đòn trước ngực',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex007',
    name: 'Seated Cable Row',
    muscleGroup: 'Lưng',
    description: 'Kéo cáp ngồi',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex008',
    name: 'Bent Over Barbell Row',
    muscleGroup: 'Lưng',
    description: 'Kéo đòn úp người',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex009',
    name: 'Squat',
    muscleGroup: 'Chân',
    description: 'Ngồi sâu với thanh tạ trên vai',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex010',
    name: 'Romanian Deadlift',
    muscleGroup: 'Chân',
    description: 'Nâng tạ từ sàn bằng cơ chân sau',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex011',
    name: 'Leg Press',
    muscleGroup: 'Chân',
    description: 'Đẩy tạ bằng chân trên máy',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex012',
    name: 'Shoulder Press',
    muscleGroup: 'Vai',
    description: 'Đẩy tạ lên trên đầu',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex013',
    name: 'Lateral Raise',
    muscleGroup: 'Vai',
    description: 'Nâng tạ đơn ra hai bên',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex014',
    name: 'Biceps Curl',
    muscleGroup: 'Tay',
    description: 'Uốn tay trước bằng tạ đơn',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex015',
    name: 'Triceps Pushdown',
    muscleGroup: 'Tay',
    description: 'Đẩy cáp xuống sau vai',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex016',
    name: 'Plank',
    muscleGroup: 'Cơ bụng',
    description: 'Giữ tư thế supports cơ bụng',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex017',
    name: 'Deadlift',
    muscleGroup: 'Chân',
    description: 'Nâng tạ từ sàn bằng toàn thân',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex018',
    name: 'Leg Extension',
    muscleGroup: 'Chân',
    description: 'Duỗi chân trên máy',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex019',
    name: 'Leg Curl',
    muscleGroup: 'Chân',
    description: 'Uốn chân trên máy',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex020',
    name: 'Calf Raise',
    muscleGroup: 'Chân',
    description: 'Nâng gót chân',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex021',
    name: 'Front Raise',
    muscleGroup: 'Vai',
    description: 'Nâng tạ đơn về phía trước',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex022',
    name: 'Rear Delt Fly',
    muscleGroup: 'Vai',
    description: 'Kéo tạ đơn ra sau vai',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex023',
    name: 'Hammer Curl',
    muscleGroup: 'Tay',
    description: 'Uốn tay trước cầmолот',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex024',
    name: 'Triceps Extension',
    muscleGroup: 'Tay',
    description: 'Duỗi tay sau đầu',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex025',
    name: 'Cable Crunch',
    muscleGroup: 'Cơ bụng',
    description: 'Uốn người bằng cáp',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex026',
    name: 'Hanging Leg Raise',
    muscleGroup: 'Cơ bụng',
    description: 'Nâng chân trên xà',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex027',
    name: 'Incline Bench Press',
    muscleGroup: 'Ngực',
    description: 'Đẩy tạ nghiêng lên trên',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex028',
    name: 'Dumbbell Fly',
    muscleGroup: 'Ngực',
    description: 'Mở tạ đơn ra hai bên',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex029',
    name: 'Pull-up',
    muscleGroup: 'Lưng',
    description: 'Nhảy xà',
    imageUrl: '',
  ),
  Exercise(
    id: 'ex030',
    name: 'T-Bar Row',
    muscleGroup: 'Lưng',
    description: 'Kéo T-bar',
    imageUrl: '',
  ),
].map(_withExerciseMetadata).toList(growable: false);
