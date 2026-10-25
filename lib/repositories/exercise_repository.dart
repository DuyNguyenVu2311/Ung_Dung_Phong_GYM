import 'package:flutter/material.dart';
import '../models/data_models.dart';

class ExerciseRepository {
  static final List<Exercise> exercises = defaultExercises;

  static List<Exercise> getAll() => List.unmodifiable(exercises);

  static List<Exercise> filter({String? muscleGroup, String? query}) {
    return exercises.where((e) {
      final matchMuscle = muscleGroup == null || e.muscleGroup == muscleGroup;
      final matchQuery = query == null ||
          query.isEmpty ||
          e.name.toLowerCase().contains(query.toLowerCase()) ||
          e.muscleGroup.toLowerCase().contains(query.toLowerCase());
      return matchMuscle && matchQuery;
    }).toList();
  }

  static Exercise findById(String id) => exercises.firstWhere(
        (e) => e.id == id,
        orElse: () => exercises.first,
      );
}
