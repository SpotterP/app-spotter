import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../providers/auth_provider.dart';
import '../services/http_client.dart';
import '../services/workout_service.dart';
import '../theme/app_colors.dart';

// Pestaña "Calendario": enseña la semana con las rutinas de cada día.
// Se puede asignar una rutina a un día o quitarla. Se guarda en el campo days de la rutina.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<Workout>? _workouts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Pide las rutinas a la API (GET /users/me/workouts)
  Future<void> _load() async {
    final auth = context.read<AuthProvider>();

    try {
      final workouts = await WorkoutService.myWorkouts(auth);
      if (!mounted) return;
      setState(() {
        _workouts = workouts;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  // Guarda los nuevos días de una rutina y recarga el calendario.
  // Se usa tanto para asignar un día como para quitarlo.
  Future<void> _saveDays(Workout workout, List<String> days) async {
    final auth = context.read<AuthProvider>();

    try {
      await WorkoutService.updateMyWorkoutDays(auth, workout, days);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    _load();
  }

  // Abre un selector con las rutinas que todavía no están asignadas a ese día
  // y, al elegir una, le añade el día
  Future<void> _assign(String day, List<Workout> workouts) async {
    final available = workouts.where((w) => !w.days.contains(day)).toList();

    final chosen = await showModalBottomSheet<Workout>(
      context: context,
      builder: (_) => available.isEmpty
          ? const Center(child: Text('No quedan rutinas por asignar'))
          : ListView(
              children: [
                for (final workout in available)
                  ListTile(title: Text(workout.name), onTap: () => Navigator.of(context).pop(workout)),
              ],
            ),
    );

    if (chosen != null) {
      _saveDays(chosen, [...chosen.days, day]);
    }
  }

  // Quita un día de la rutina
  void _remove(String day, Workout workout) {
    _saveDays(workout, workout.days.where((d) => d != day).toList());
  }

  @override
  Widget build(BuildContext context) {
    final workouts = _workouts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
        // Por si las rutinas han cambiado en otra pestaña
        actions: [IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualizar', onPressed: _load)],
      ),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))
          : workouts == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final (key, label) in weekDays) _buildDay(key, label, workouts),
                  ],
                ),
    );
  }

  // Un día de la semana: su nombre, las rutinas asignadas (con una x para quitarlas)
  // y un botón para asignar otra
  Widget _buildDay(String day, String label, List<Workout> workouts) {
    final ofDay = workouts.where((w) => w.days.contains(day)).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 90, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  // El gris del texto apagado sale del tema para que se vea bien en claro y en oscuro
                  if (ofDay.isEmpty) Text('Sin rutina', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  for (final workout in ofDay)
                    InputChip(label: Text(workout.name), onDeleted: () => _remove(day, workout)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Asignar rutina',
              onPressed: () => _assign(day, workouts),
            ),
          ],
        ),
      ),
    );
  }
}
