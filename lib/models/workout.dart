// Un ejercicio del catálogo (lo que devuelve GET /exercises)
class Exercise {
  final String id;
  final String name;
  // Categoría en inglés: CHEST, BACK, LEGS, SHOULDERS, ARMS, CORE o CARDIO
  final String category;

  Exercise({required this.id, required this.name, this.category = ''});

  // La API manda el id como "_id"
  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(id: json['_id'] ?? '', name: json['name'] ?? '', category: json['category'] ?? '');
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
  // Días de la semana en los que se hace la rutina (para el calendario).
  // La API los manda en inglés: MONDAY, TUESDAY... SUNDAY
  final List<String> days;
  final List<WorkoutExercise> exercises;

  Workout({required this.id, required this.name, required this.days, required this.exercises});

  // Convierte el JSON de la API en una Workout.
  // Cada ejercicio de la rutina llega con el ejercicio completo dentro (populate).
  // Si ya no existe en el catálogo llega como null y lo saltamos.
  factory Workout.fromJson(Map<String, dynamic> json) {
    final items = (json['exercises'] as List? ?? []).where((item) => item['exercise'] is Map);

    return Workout(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      days: (json['days'] as List? ?? []).map((d) => d.toString()).toList(),
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
