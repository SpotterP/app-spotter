import '../models/workout.dart';
import '../providers/auth_provider.dart';

// Llamadas a la API de rutinas.
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
}
