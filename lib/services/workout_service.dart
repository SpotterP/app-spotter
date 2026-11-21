import '../models/workout.dart';
import '../providers/auth_provider.dart';

// Llamadas a la API de rutinas y ejercicios.
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
}
