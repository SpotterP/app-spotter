import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../providers/auth_provider.dart';
import '../services/http_client.dart';
import '../services/workout_service.dart';
import 'training_session_screen.dart';

// Pestaña "Entrenar": un botón de play para empezar un entrenamiento. Al pulsarlo, la app propone
// las rutinas asignadas al día de hoy en el calendario y deja elegir cualquier otra rutina
// o empezar un entrenamiento vacío.
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  // true mientras se piden las rutinas a la API
  bool _loading = false;

  // Pide las rutinas, enseña las opciones y abre el entrenamiento que elija el usuario
  Future<void> _play() async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);

    List<Workout> workouts;
    try {
      workouts = await WorkoutService.myWorkouts(auth);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);

    // choice es null si se cierra el menú sin elegir. Si se elige entrenamiento vacío,
    // choice.workout es null
    final choice = await showModalBottomSheet<({Workout? workout})>(
      context: context,
      builder: (_) => _buildOptions(workouts),
    );

    if (choice == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrainingSessionScreen(workout: choice.workout)));
  }

  // El menú de opciones: primero las rutinas de hoy, luego el resto y por último el entrenamiento vacío
  Widget _buildOptions(List<Workout> workouts) {
    // DateTime.weekday va de 1 (lunes) a 7 (domingo), y la lista weekDays empieza en lunes
    final (todayKey, todayLabel) = weekDays[DateTime.now().weekday - 1];
    final today = workouts.where((w) => w.days.contains(todayKey)).toList();
    final others = workouts.where((w) => !w.days.contains(todayKey)).toList();

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          if (today.isNotEmpty) ...[
            _header('Hoy toca ($todayLabel)'),
            for (final workout in today)
              ListTile(
                leading: const Icon(Icons.star),
                title: Text(workout.name),
                onTap: () => Navigator.of(context).pop((workout: workout)),
              ),
          ],
          if (others.isNotEmpty) ...[
            _header(today.isNotEmpty ? 'Otras rutinas' : 'Tus rutinas'),
            for (final workout in others)
              ListTile(
                leading: const Icon(Icons.fitness_center),
                title: Text(workout.name),
                onTap: () => Navigator.of(context).pop((workout: workout)),
              ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Entrenamiento vacío'),
            onTap: () => Navigator.of(context).pop((workout: null)),
          ),
        ],
      ),
    );
  }

  // Título pequeño de cada grupo del menú
  Widget _header(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entrenar')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Listo para entrenar?', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading ? null : _play,
              icon: const Icon(Icons.play_arrow),
              label: Text(_loading ? 'Cargando…' : 'Empezar entrenamiento'),
            ),
          ],
        ),
      ),
    );
  }
}
