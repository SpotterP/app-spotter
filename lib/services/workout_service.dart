import '../models/training.dart';
import '../models/workout.dart';
import '../providers/auth_provider.dart';

// Llamadas a la API de rutinas, ejercicios y entrenamientos.
// Son rutas protegidas, así que usan auth.authorizedRequest (manda el token y lo renueva si caduca).
class WorkoutService {
  // GET /users/me/workouts. Las rutinas del usuario
  static Future<List<Workout>> myWorkouts(AuthProvider auth) async {
    final data = await auth.authorizedRequest('/users/me/workouts');

    return (data['workouts'] as List).map((w) => Workout.fromJson(w)).toList();
  }

  // POST /users/me/workouts. Crea una rutina del usuario solo con el nombre
  static Future<void> createMyWorkout(AuthProvider auth, String name) async {
    await auth.authorizedRequest('/users/me/workouts', method: 'POST', body: {'name': name});
  }

  // DELETE /users/me/workouts/:id. Borra una rutina del usuario
  static Future<void> deleteMyWorkout(AuthProvider auth, String id) async {
    await auth.authorizedRequest('/users/me/workouts/$id', method: 'DELETE');
  }

  // GET /users/me/workouts/:id. Una rutina del usuario con sus ejercicios
  static Future<Workout> myWorkout(AuthProvider auth, String id) async {
    final data = await auth.authorizedRequest('/users/me/workouts/$id');

    return Workout.fromJson(data['workout']);
  }

  // GET /exercises. Una página del catálogo de ejercicios, ordenado por nombre.
  // search: texto que tiene que contener el nombre (no distingue mayúsculas). category: solo esa categoría.
  // Devuelve los ejercicios de la página y si hay otra página después de esta.
  static Future<({List<Exercise> exercises, bool hasNextPage})> exercises(
    AuthProvider auth, {
    required int page,
    String search = '',
    String? category,
  }) async {
    final query = [
      'limit=20',
      'page=$page',
      'sort=name',
      'order=asc',
      // Uri.encodeQueryComponent cambia los espacios y los acentos para que viajen bien en la URL
      if (search.isNotEmpty) 'search=${Uri.encodeQueryComponent(search)}',
      if (category != null) 'category=$category',
    ].join('&');

    final data = await auth.authorizedRequest('/exercises?$query');

    return (
      exercises: (data['exercises'] as List).map((e) => Exercise.fromJson(e)).toList(),
      hasNextPage: data['pagination']['hasNextPage'] == true,
    );
  }

  // PUT /users/me/workouts/:id. Guarda solo los días de la semana de la rutina.
  // La API exige el nombre al actualizar, pero los ejercicios son opcionales:
  // si no se mandan, se quedan como estaban.
  static Future<void> updateMyWorkoutDays(AuthProvider auth, Workout workout, List<String> days) async {
    await auth.authorizedRequest(
      '/users/me/workouts/${workout.id}',
      method: 'PUT',
      body: {'name': workout.name, 'days': days},
    );
  }

  // PUT /users/me/workouts/:id. Guarda el nombre y los ejercicios de la rutina.
  // El orden de la lista es el orden en que se guardan los ejercicios.
  static Future<void> updateMyWorkout(AuthProvider auth, String id, String name, List<WorkoutExercise> exercises) async {
    await auth.authorizedRequest(
      '/users/me/workouts/$id',
      method: 'PUT',
      body: {
        'name': name,
        'exercises': exercises.map((e) => {'exercise': e.exercise.id, 'sets': e.sets, 'reps': e.reps}).toList(),
      },
    );
  }

  // POST /users/me/sessions. Guarda un entrenamiento terminado.
  // workoutId es la rutina que se hizo; se omite si el entrenamiento se empezó de cero.
  // El fin del entrenamiento es el momento en que se llama a esta función.
  // Solo mandamos los ejercicios en los que se ha apuntado alguna serie.
  static Future<void> saveSession(
    AuthProvider auth, {
    String? workoutId,
    required DateTime startedAt,
    required List<ActiveExercise> exercises,
  }) async {
    await auth.authorizedRequest(
      '/users/me/sessions',
      method: 'POST',
      body: {
        if (workoutId != null) 'workout': workoutId,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'finishedAt': DateTime.now().toUtc().toIso8601String(),
        'exercises': [
          for (final e in exercises)
            if (e.sets.isNotEmpty)
              {
                'exercise': e.exercise.id,
                'sets': [for (final s in e.sets) {'reps': s.reps, 'weight': s.weight}],
              },
        ],
      },
    );
  }
}
