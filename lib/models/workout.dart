// Un ejercicio del catálogo (lo que devuelve GET /exercises)
class Exercise {
  final String id;
  final String name;

  Exercise({required this.id, required this.name});

  // La API manda el id como "_id"
  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(id: json['_id'] ?? '', name: json['name'] ?? '');
  }
}

// Un ejercicio dentro de una rutina, con sus propias series y repeticiones.
// sets y reps no son final porque la pantalla de editar los cambia.
class WorkoutExercise {
  final Exercise exercise;
  int sets;
  int reps;

  WorkoutExercise({required this.exercise, required this.sets, required this.reps});
}

// Una rutina del usuario. El orden de la lista exercises es el orden de la rutina
class Workout {
  final String id;
  final String name;
  final List<WorkoutExercise> exercises;

  Workout({required this.id, required this.name, required this.exercises});

  // Convierte el JSON de la API en una Workout.
  // Cada ejercicio de la rutina llega con el ejercicio completo dentro (populate).
  // Si ya no existe en el catálogo llega como null y lo saltamos.
  factory Workout.fromJson(Map<String, dynamic> json) {
    final items = (json['exercises'] as List? ?? []).where((item) => item['exercise'] is Map);

    return Workout(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      exercises: items
          .map((item) => WorkoutExercise(
                exercise: Exercise.fromJson(item['exercise']),
                sets: item['sets'] ?? 3,
                reps: item['reps'] ?? 10,
              ))
          .toList(),
    );
  }
}
