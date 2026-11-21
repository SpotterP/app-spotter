import '../models/progress.dart';
import '../providers/auth_provider.dart';

// Llamadas a la API del progreso del usuario.
// Son rutas protegidas, así que usan auth.authorizedRequest (manda el token y lo renueva si caduca).
class ProgressService {
  // GET /users/me/progress. Número de entrenamientos, días entrenados y ejercicios hechos
  static Future<Progress> progress(AuthProvider auth) async {
    final data = await auth.authorizedRequest('/users/me/progress');

    return Progress.fromJson(data['progress']);
  }

  // GET /users/me/sessions. Los entrenamientos realizados, del más reciente al más antiguo.
  // Pedimos 100, que es el máximo que da la API en una página.
  static Future<List<TrainingSession>> sessions(AuthProvider auth) async {
    final data = await auth.authorizedRequest('/users/me/sessions?limit=100');

    return (data['sessions'] as List).map((s) => TrainingSession.fromJson(s)).toList();
  }

  // GET /users/me/workouts. Solo nos hace falta el nombre de cada rutina, por su id.
  // La API del entrenamiento solo manda el id de la rutina, no su nombre.
  static Future<Map<String, String>> workoutNames(AuthProvider auth) async {
    final data = await auth.authorizedRequest('/users/me/workouts');

    return {for (final w in data['workouts'] as List) w['_id'] as String: (w['name'] ?? '') as String};
  }
}
