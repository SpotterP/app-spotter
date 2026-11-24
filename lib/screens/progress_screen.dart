import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/progress.dart';
import '../providers/auth_provider.dart';
import '../services/http_client.dart';
import '../services/progress_service.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Pide el resumen, los entrenamientos y los nombres de las rutinas a la vez
  Future<void> _load() async {
    final auth = context.read<AuthProvider>();

    try {
      final results = await Future.wait([
        ProgressService.progress(auth),
        ProgressService.sessions(auth),
        ProgressService.workoutNames(auth),
      ]);
      if (!mounted) return;

      setState(() {
        _progress = results[0] as Progress;
        _sessions = results[1] as List<TrainingSession>;
        _workoutNames = results[2] as Map<String, String>;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
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
                  ],
                ),
    );
  }

  // El resumen: número de entrenamientos, días entrenados y ejercicios hechos
  Widget _buildSummary(Progress progress) {
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
            if (progress.trainedDays.isEmpty) const Text('Ninguno todavía'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [for (final day in progress.trainedDays) Chip(label: Text(formatDay(day)))],
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
