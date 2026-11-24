import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/progress.dart';
import '../providers/auth_provider.dart';
import '../services/http_client.dart';
import '../services/progress_service.dart';
import '../services/socket_service.dart';
import '../theme/app_colors.dart';
import 'session_detail_screen.dart';

// Pestaña "Progreso": el resumen del usuario (entrenamientos, días y ejercicios)
// y la lista de entrenamientos realizados. Al tocar uno se ve su detalle.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  Progress? _progress;
  List<TrainingSession> _sessions = [];
  // Nombre de cada rutina por su id, para enseñar la rutina de cada entrenamiento
  Map<String, String> _workoutNames = {};
  String? _error;

  // Historial paginado: pide las páginas al backend y las junta sin repetir ni perder sesiones
  SessionsPager? _pager;
  // true mientras se trae la página siguiente (para no pedirla dos veces a la vez)
  bool _loadingMore = false;
  // Error al traer más entrenamientos: se enseña junto al botón, sin tirar la lista que ya hay
  String? _loadMoreError;

  // Conexión en tiempo real: avisa cuando se guarda un entrenamiento nuevo
  final _socket = SocketService();

  @override
  void initState() {
    super.initState();
    _startRealtime();
  }

  @override
  void dispose() {
    // Al cerrar sesión se quita la pantalla principal y con ella esta pantalla: cerramos la conexión
    _socket.disconnect();
    super.dispose();
  }

  // Carga los datos y despues abre la conexion en tiempo real.
  // Esperamos a la primera carga porque si el token habia caducado, aqui se renueva
  // y asi el socket se conecta ya con un token que vale.
  Future<void> _startRealtime() async {
    final auth = context.read<AuthProvider>();

    await _load();
    if (!mounted) return;

    // Cuando llega un entrenamiento nuevo, volvemos a pedir el resumen y la lista
    _socket.connect(() => auth.token, _load);
  }

  // Pide el resumen, la primera página de entrenamientos y los nombres de las rutinas a la vez
  Future<void> _load() async {
    final auth = context.read<AuthProvider>();

    // Cada carga vuelve a empezar por la primera página: si refrescamos (o llega un entrenamiento
    // nuevo), la lista no puede quedarse a medias con lo que había antes
    final pager = SessionsPager(auth);

    try {
      final results = await Future.wait([
        ProgressService.progress(auth),
        pager.loadNext(),
        ProgressService.workoutNames(auth),
      ]);
      if (!mounted) return;

      setState(() {
        _progress = results[0] as Progress;
        _pager = pager;
        _sessions = pager.sessions;
        _workoutNames = results[2] as Map<String, String>;
        _loadingMore = false;
        _loadMoreError = null;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _error = e.message;
      });
    }
  }

  // Trae la página siguiente del historial. Qué página toca lo decide el backend: el paginador
  // usa su "pagination", así que aquí no hay ningún contador de páginas que se pueda desincronizar.
  Future<void> _loadMore() async {
    final pager = _pager;
    if (pager == null || _loadingMore || !pager.hasMore) return;

    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });

    try {
      await pager.loadNext();
      // Si mientras tanto la pantalla se ha recargado, esta página ya no vale para la lista nueva
      if (!mounted || !identical(_pager, pager)) return;

      setState(() {
        _sessions = pager.sessions;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted || !identical(_pager, pager)) return;
      setState(() {
        _loadMoreError = e.message;
        _loadingMore = false;
      });
    }
  }

  // Nombre de la rutina de un entrenamiento. Sin rutina, es un entrenamiento libre.
  // Si tiene rutina pero ya no está en la lista, es que se borró.
  String _routineName(TrainingSession session) {
    if (session.workoutId == null) return 'Entrenamiento libre';
    return _workoutNames[session.workoutId] ?? 'Rutina borrada';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progreso'),
        actions: [IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualizar', onPressed: _load)],
      ),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))
          : progress == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSummary(progress),
                    const SizedBox(height: 24),
                    const Text('Entrenamientos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_sessions.isEmpty) const Text('Todavía no has hecho ningún entrenamiento'),
                    for (final session in _sessions)
                      Card(
                        child: ListTile(
                          title: Text(_routineName(session)),
                          subtitle: Text(formatDate(session.startedAt)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SessionDetailScreen(session: session, routineName: _routineName(session)),
                          )),
                        ),
                      ),
                    // «Cargar más» solo aparece mientras el backend diga que hay más páginas
                    if (_pager?.hasMore ?? false) ...[
                      const SizedBox(height: 8),
                      if (_loadingMore)
                        // Mientras carga se dice qué está pasando, para que no parezca que se ha colgado
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 8),
                              Text('Cargando más entrenamientos...'),
                            ],
                          ),
                        )
                      else ...[
                        if (_loadMoreError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _loadMoreError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.danger),
                            ),
                          ),
                        Center(
                          child: OutlinedButton(
                            onPressed: _loadMore,
                            child: Text(_loadMoreError == null
                                ? 'Cargar más entrenamientos'
                                : 'Reintentar'),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
    );
  }

  // El resumen: número de entrenamientos, días entrenados y ejercicios hechos.
  // El total y los ejercicios vienen tal cual de GET /users/me/progress; los días entrenados
  // se calculan en local con las sesiones ya cargadas, para que el calendario y la lista de
  // abajo digan el mismo día (el backend los agrupa en UTC y una sesión de noche se iba al día
  // anterior). Si hay más páginas sin cargar, los días son los del historial cargado.
  Widget _buildSummary(Progress progress) {
    final trainedDays = localTrainedDays(_sessions);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${progress.totalSessions}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
            const Text('entrenamientos', style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 16),
            const Text('Días que has entrenado', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (trainedDays.isEmpty) const Text('Ninguno todavía'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [for (final day in trainedDays) Chip(label: Text(formatDay(day)))],
            ),
            const SizedBox(height: 16),
            const Text('Ejercicios que has hecho', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (progress.exercises.isEmpty) const Text('Ninguno todavía'),
            for (final exercise in progress.exercises)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(exercise.name)),
                    Text(exercise.timesDone == 1 ? '1 vez' : '${exercise.timesDone} veces'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
