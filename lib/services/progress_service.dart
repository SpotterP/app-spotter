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
  // La API pagina: pedimos una página (page empieza en 1) y devolvemos la lista con sus metadatos.
  // limit=100 es el máximo que acepta el backend, para traer el menor número de páginas posible.
  static const sessionsPerPage = 100;

  static Future<SessionsPage> sessionsPage(AuthProvider auth, {int page = 1}) async {
    final data = await auth.authorizedRequest('/users/me/sessions?page=$page&limit=$sessionsPerPage');

    return SessionsPage.fromJson(data);
  }

  // GET /users/me/workouts. Solo nos hace falta el nombre de cada rutina, por su id.
  // La API del entrenamiento solo manda el id de la rutina, no su nombre.
  static Future<Map<String, String>> workoutNames(AuthProvider auth) async {
    final data = await auth.authorizedRequest('/users/me/workouts');

    return {for (final w in data['workouts'] as List) w['_id'] as String: (w['name'] ?? '') as String};
  }
}

// Va pidiendo páginas de entrenamientos y las junta en una sola lista.
// La página siguiente es la que dice el backend (pagination.page + 1) y se para cuando el
// backend contesta que no hay más, así que no hay un contador propio que se pueda desincronizar.
class SessionsPager {
  SessionsPager(this.auth);

  final AuthProvider auth;

  // Los entrenamientos juntados hasta ahora
  final _sessions = <TrainingSession>[];
  final _ids = <String>{};

  // Página que toca pedir. Empieza en 1 y pasa a null cuando ya no hay más
  int? _nextPage = 1;

  // Lista de solo lectura, para que nadie de fuera la modifique por su cuenta
  List<TrainingSession> get sessions => List.unmodifiable(_sessions);

  int? get nextPage => _nextPage;
  bool get hasMore => _nextPage != null;

  // Pide la página que toca y la junta con las que ya había.
  // Si el backend ya dijo que no hay más, no pide nada (la pantalla puede llamar sin miedo).
  Future<void> loadNext() async {
    final page = _nextPage;
    if (page == null) return;

    final result = await ProgressService.sessionsPage(auth, page: page);

    _merge(result.sessions);
    _nextPage = result.nextPage;
  }

  // Junta una página sin repetir sesiones. Una sesión puede venir en dos páginas seguidas:
  // si mientras el usuario baja se guarda un entrenamiento nuevo, las filas se desplazan
  // y la última de una página vuelve a salir la primera de la siguiente.
  // Se ordena del más reciente al más antiguo, como manda la API; el id desempata para que
  // dos entrenamientos empezados en el mismo segundo no bailen entre cargas.
  void _merge(List<TrainingSession> page) {
    for (final session in page) {
      if (_ids.add(session.id)) _sessions.add(session);
    }

    _sessions.sort((a, b) {
      final byDate = b.startedAt.compareTo(a.startedAt);
      return byDate != 0 ? byDate : b.id.compareTo(a.id);
    });
  }
}
