// Un ejercicio hecho, con las veces que se ha hecho (dentro del resumen de progreso)
class ProgressExercise {
  final String name;
  final int timesDone;

  ProgressExercise({required this.name, required this.timesDone});
}

// Resumen del progreso del usuario (lo que devuelve GET /users/me/progress)
class Progress {
  final int totalSessions;
  // Días en los que entrenó, como texto AAAA-MM-DD y sin repetir
  final List<String> trainedDays;
  final List<ProgressExercise> exercises;

  Progress({required this.totalSessions, required this.trainedDays, required this.exercises});

  factory Progress.fromJson(Map<String, dynamic> json) {
    return Progress(
      totalSessions: json['totalSessions'] ?? 0,
      trainedDays: (json['trainedDays'] as List? ?? []).map((d) => d.toString()).toList(),
      exercises: (json['exercises'] as List? ?? [])
          .map((e) => ProgressExercise(name: e['exercise']['name'] ?? '', timesDone: e['timesDone'] ?? 0))
          .toList(),
    );
  }
}

// Una serie que hizo el usuario: repeticiones y peso en kg
class SessionSet {
  final int reps;
  final num weight;

  SessionSet({required this.reps, required this.weight});
}

// Un ejercicio de un entrenamiento con las series que se hicieron
class SessionExercise {
  final String name;
  final List<SessionSet> sets;

  SessionExercise({required this.name, required this.sets});
}

// Un entrenamiento realizado (lo que devuelve GET /users/me/sessions).
// Se llama TrainingSession para no confundirlo con la Session del login.
class TrainingSession {
  final String id;
  // Id de la rutina que se hizo. Es null si el entrenamiento se empezó de cero ("Entrenamiento libre")
  final String? workoutId;
  final DateTime startedAt;
  final List<SessionExercise> exercises;

  TrainingSession({required this.id, required this.workoutId, required this.startedAt, required this.exercises});

  // Los ejercicios llegan completos (populate), así que se lee su nombre.
  // Si un ejercicio ya no existe en el catálogo llega como null y se salta.
  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    final items = (json['exercises'] as List? ?? []).where((item) => item['exercise'] is Map);

    return TrainingSession(
      id: json['_id'] ?? '',
      workoutId: json['workout'],
      startedAt: DateTime.parse(json['startedAt']).toLocal(),
      exercises: items
          .map((item) => SessionExercise(
                name: item['exercise']['name'] ?? '',
                sets: (item['sets'] as List? ?? [])
                    .map((s) => SessionSet(reps: s['reps'] ?? 0, weight: s['weight'] ?? 0))
                    .toList(),
              ))
          .toList(),
    );
  }
}

// Una página de entrenamientos, con el bloque "pagination" que manda la API
// (page, limit, total, totalPages, hasNextPage, hasPrevPage).
class SessionsPage {
  final List<TrainingSession> sessions;
  // La página que ha devuelto el backend (empieza en 1)
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasNextPage;

  SessionsPage({
    required this.sessions,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasNextPage,
  });

  // La página que hay que pedir después, o null si el backend dice que no hay más.
  // Sale del "page" que devuelve el backend, no de un contador propio que se pueda desincronizar.
  int? get nextPage => hasNextPage ? page + 1 : null;

  factory SessionsPage.fromJson(Map<String, dynamic> json) {
    final pagination = (json['pagination'] as Map?) ?? const {};
    final page = (pagination['page'] as num?)?.toInt() ?? 1;
    final limit = (pagination['limit'] as num?)?.toInt() ?? 0;
    final total = (pagination['total'] as num?)?.toInt() ?? 0;

    return SessionsPage(
      sessions: (json['sessions'] as List? ?? []).map((s) => TrainingSession.fromJson(s)).toList(),
      page: page,
      limit: limit,
      total: total,
      totalPages: (pagination['totalPages'] as num?)?.toInt() ?? page,
      // Si el backend no manda la paginación, damos la página por última: mejor quedarse corto
      // que pedir páginas para siempre
      hasNextPage: pagination['hasNextPage'] as bool? ?? false,
    );
  }
}

// Enseña una fecha como día/mes/año ("5/3/2026")
String formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

// Convierte un día de la API ("2026-03-05") a día/mes/año ("5/3/2026")
String formatDay(String day) {
  final parts = day.split('-');
  if (parts.length != 3) return day;
  return '${int.parse(parts[2])}/${int.parse(parts[1])}/${parts[0]}';
}
