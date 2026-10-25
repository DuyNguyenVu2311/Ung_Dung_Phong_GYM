import 'dart:convert';

class UserProfile {
  final String name;
  final int age;
  final double height;
  final double weight;
  final String gender;
  final String goal;
  final String experienceLevel;
  final int sessionsPerWeek;

  UserProfile({
    required this.name,
    required this.age,
    required this.height,
    required this.weight,
    required this.gender,
    required this.goal,
    required this.experienceLevel,
    required this.sessionsPerWeek,
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

  Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.description,
    required this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'muscleGroup': muscleGroup,
        'description': description,
        'imageUrl': imageUrl,
      };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        muscleGroup: json['muscleGroup'] ?? '',
        description: json['description'] ?? '',
        imageUrl: json['imageUrl'] ?? '',
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

  WorkoutSession({
    required this.id,
    required this.dayName,
    required this.date,
    required this.logs,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'dayName': dayName,
        'date': date.toIso8601String(),
        'logs': logs.map((l) => l.toJson()).toList(),
      };

  String toJsonString() => jsonEncode(toJson());

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
        id: json['id'] ?? '',
        dayName: json['dayName'] ?? '',
        date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
        logs: (json['logs'] as List? ?? [])
            .map((l) => ExerciseLog.fromJson(l))
            .toList(),
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

  ExerciseLog({
    required this.id,
    required this.sessionId,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    required this.weight,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'exerciseName': exerciseName,
        'sets': sets,
        'reps': reps,
        'weight': weight,
      };

  factory ExerciseLog.fromJson(Map<String, dynamic> json) => ExerciseLog(
        id: json['id'] ?? '',
        sessionId: json['sessionId'] ?? '',
        exerciseName: json['exerciseName'] ?? '',
        sets: json['sets'] ?? 0,
        reps: json['reps'] ?? 0,
        weight: json['weight'] ?? 0.0,
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

List<Exercise> defaultExercises = [
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
];
