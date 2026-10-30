import '../models/data_models.dart';
import 'muscle_program_catalog.dart';

class ExerciseRepository {
  static final List<Exercise> exercises = {
    for (final exercise in defaultExercises) exercise.id: exercise,
    for (final exercise in MuscleProgramCatalog.exercises)
      exercise.id: exercise,
  }.values.toList(growable: false);

  static List<Exercise> getAll() => List.unmodifiable(exercises);

  static List<Exercise> filter({String? muscleGroup, String? query}) {
    return exercises.where((e) {
      final matchMuscle =
          muscleGroup == null ||
          e.muscleGroup == muscleGroup ||
          e.focusGroup == muscleGroup;
      final matchQuery =
          query == null ||
          query.isEmpty ||
          e.name.toLowerCase().contains(query.toLowerCase()) ||
          e.muscleGroup.toLowerCase().contains(query.toLowerCase()) ||
          e.focusGroup.toLowerCase().contains(query.toLowerCase()) ||
          e.targetArea.toLowerCase().contains(query.toLowerCase());
      return matchMuscle && matchQuery;
    }).toList();
  }

  static Exercise findById(String id) =>
      exercises.firstWhere((e) => e.id == id, orElse: () => exercises.first);
}
