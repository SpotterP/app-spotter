import 'workout.dart';

// Una serie que el usuario ha apuntado durante el entrenamiento: repeticiones y peso en kg
class ActiveSet {
  final int reps;
  final double weight;

  ActiveSet({required this.reps, required this.weight});
}

// Un ejercicio del entrenamiento en curso, con las series que se van apuntando
class ActiveExercise {
  final Exercise exercise;
  // Lo que la rutina tenía previsto. Es null si el ejercicio se añadió sobre la marcha
  final int? plannedSets;
  final int? plannedReps;
  final List<ActiveSet> sets = [];

  ActiveExercise({required this.exercise, this.plannedSets, this.plannedReps});
}
