import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/progress.dart';
import '../models/training.dart';
import '../models/workout.dart';
import '../providers/auth_provider.dart';
import '../services/http_client.dart';
import '../services/workout_service.dart';
import '../theme/app_colors.dart';
import 'exercise_picker_screen.dart';

// Entrenamiento en curso. Si recibe una rutina, enseña sus ejercicios en orden con las series y
// repeticiones previstas. Si no (workout null), empieza vacío y se van añadiendo ejercicios.
// En cada ejercicio se apuntan las series hechas. Al finalizar se guarda (POST /users/me/sessions).
class TrainingSessionScreen extends StatefulWidget {
  final Workout? workout;

  const TrainingSessionScreen({super.key, this.workout});

  @override
  State<TrainingSessionScreen> createState() => _TrainingSessionScreenState();
}

class _TrainingSessionScreenState extends State<TrainingSessionScreen> {
  // Momento en que se empezó el entrenamiento
  final _startedAt = DateTime.now();

  // Ejercicios del entrenamiento, en orden
  late final List<ActiveExercise> _exercises;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Con rutina, partimos de sus ejercicios y de lo que tenía previsto en cada uno
    _exercises = (widget.workout?.exercises ?? [])
        .map((e) => ActiveExercise(exercise: e.exercise, plannedSets: e.sets, plannedReps: e.reps))
        .toList();
  }

  // Abre el selector de ejercicios y añade el elegido al final del entrenamiento
  Future<void> _addExercise() async {
    final chosen = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => ExercisePickerScreen(selectedIds: _exercises.map((e) => e.exercise.id).toSet())),
    );

    if (chosen != null) {
      setState(() => _exercises.add(ActiveExercise(exercise: chosen)));
    }
  }

  // Pide confirmación y, si el usuario acepta, descarta el entrenamiento y vuelve atrás
  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar entrenamiento'),
        content: const Text('Se perderá lo que has apuntado. ¿Seguro que quieres cancelarlo?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Seguir entrenando')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) Navigator.of(context).pop();
  }

  // Guarda el entrenamiento (POST /users/me/sessions) y vuelve al inicio
  Future<void> _finish() async {
    // Si no se ha apuntado ninguna serie no hay nada que guardar
    if (_exercises.every((e) => e.sets.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Apunta al menos una serie antes de finalizar')));
      return;
    }

    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    try {
      await WorkoutService.saveSession(auth, workoutId: widget.workout?.id, startedAt: _startedAt, exercises: _exercises);
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _saving = false);
      return;
    }

    messenger.showSnackBar(const SnackBar(content: Text('Entrenamiento guardado')));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // canPop false: el botón de atrás del móvil no sale directamente, pide confirmación como Cancelar
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.workout?.name ?? 'Entrenamiento libre'),
          leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Cancelar', onPressed: _cancel),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_exercises.isEmpty) const Text('Entrenamiento vacío. Añade el primer ejercicio.'),
            for (final exercise in _exercises) _ExerciseCard(key: ValueKey(exercise.exercise.id), exercise: exercise),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _addExercise, icon: const Icon(Icons.add), label: const Text('Añadir ejercicio')),
            const SizedBox(height: 24),
            FilledButton(onPressed: _saving ? null : _finish, child: Text(_saving ? 'Guardando…' : 'Finalizar')),
          ],
        ),
      ),
    );
  }
}

// Un ejercicio del entrenamiento: lo previsto, las series ya apuntadas y el formulario para apuntar otra.
// Guarda el texto de los campos, por eso es un StatefulWidget aparte.
class _ExerciseCard extends StatefulWidget {
  final ActiveExercise exercise;

  const _ExerciseCard({super.key, required this.exercise});

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  late final _repsController = TextEditingController(text: widget.exercise.plannedReps?.toString() ?? '');
  final _weightController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  // Apunta una serie con las repeticiones y el peso escritos.
  // Las repeticiones tienen que ser un entero desde 1 y el peso un número desde 0 (acepta coma o punto)
  void _addSet() {
    final reps = int.tryParse(_repsController.text.trim());
    final weight = double.tryParse(_weightController.text.trim().replaceAll(',', '.'));

    if (reps == null || reps < 1 || weight == null || weight < 0) {
      setState(() => _error = 'Escribe las repeticiones (1 o más) y el peso en kg (0 o más)');
      return;
    }

    setState(() {
      widget.exercise.sets.add(ActiveSet(reps: reps, weight: weight));
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exercise.exercise.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (exercise.plannedSets != null)
              Text(
                'Previsto: ${exercise.plannedSets} series de ${exercise.plannedReps}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            const SizedBox(height: 8),
            // Las series ya apuntadas, cada una con un botón para quitarla
            for (var i = 0; i < exercise.sets.length; i++)
              Row(
                children: [
                  Expanded(child: Text('Serie ${i + 1}: ${exercise.sets[i].reps} repeticiones con ${formatWeight(exercise.sets[i].weight)} kg')),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Quitar serie',
                    onPressed: () => setState(() => exercise.sets.removeAt(i)),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            // Formulario para apuntar una serie nueva
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _repsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Reps', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Peso (kg)', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(icon: const Icon(Icons.add), tooltip: 'Añadir serie', onPressed: _addSet),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ),
          ],
        ),
      ),
    );
  }
}
