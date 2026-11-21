import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../providers/auth_provider.dart';
import '../services/http_client.dart';
import '../services/workout_service.dart';
import '../theme/app_colors.dart';

// Pantalla para editar una rutina: cambiar el nombre, añadir ejercicios del catálogo,
// elegir sus series y repeticiones, cambiar su orden arrastrando, quitarlos y guardar.
class RoutineEditScreen extends StatefulWidget {
  final String workoutId;

  const RoutineEditScreen({super.key, required this.workoutId});

  @override
  State<RoutineEditScreen> createState() => _RoutineEditScreenState();
}

class _RoutineEditScreenState extends State<RoutineEditScreen> {
  // Controla el texto del campo del nombre
  final _nameController = TextEditingController();

  // Ejercicios de la rutina. El orden de esta lista es el orden de la rutina
  List<WorkoutExercise> _rows = [];

  // Todos los ejercicios del catálogo, para el selector
  List<Exercise> _catalog = [];

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Al abrir la pantalla pedimos la rutina y el catálogo a la vez
  Future<void> _load() async {
    final auth = context.read<AuthProvider>();

    try {
      final results = await Future.wait([
        WorkoutService.myWorkout(auth, widget.workoutId),
        WorkoutService.exercises(auth),
      ]);
      if (!mounted) return;

      final workout = results[0] as Workout;
      setState(() {
        _nameController.text = workout.name;
        _rows = workout.exercises;
        _catalog = results[1] as List<Exercise>;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  // Abre el selector con los ejercicios del catálogo que todavía no están en la rutina.
  // Al elegir uno se añade al final con 3 series de 10 por defecto.
  Future<void> _addExercise() async {
    final available = _catalog.where((e) => !_rows.any((r) => r.exercise.id == e.id)).toList();

    final chosen = await showModalBottomSheet<Exercise>(
      context: context,
      builder: (_) => available.isEmpty
          ? const Center(child: Text('No quedan ejercicios por añadir'))
          : ListView(
              children: [
                for (final exercise in available)
                  ListTile(title: Text(exercise.name), onTap: () => Navigator.of(context).pop(exercise)),
              ],
            ),
    );

    if (chosen != null) {
      setState(() => _rows.add(WorkoutExercise(exercise: chosen, sets: 3, reps: 10)));
    }
  }

  // Cambia el orden al arrastrar un ejercicio de oldIndex a newIndex
  void _reorder(int oldIndex, int newIndex) {
    // Flutter cuenta newIndex antes de sacar el ejercicio, así que hay que restar 1 al bajar
    if (newIndex > oldIndex) newIndex -= 1;

    setState(() {
      final item = _rows.removeAt(oldIndex);
      _rows.insert(newIndex, item);
    });
  }

  // Guarda la rutina (PUT /users/me/workouts/:id) con el nombre, los ejercicios y su orden
  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'La rutina necesita un nombre');
      return;
    }

    final auth = context.read<AuthProvider>();
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await WorkoutService.updateMyWorkout(auth, widget.workoutId, name, _rows);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rutina guardada')));
    } on ApiException catch (e) {
      if (!mounted) return;
      _error = e.message;
    }

    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar rutina')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  ),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                const Text('Ejercicios', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_rows.isEmpty) const Text('Esta rutina no tiene ejercicios. Añade el primero.'),
                // Lista que se puede reordenar arrastrando. Va dentro de otra lista, por eso
                // shrinkWrap (ocupa solo lo que necesita) y sin scroll propio
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorder: _reorder,
                  children: [
                    for (var i = 0; i < _rows.length; i++) _buildRow(i),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir ejercicio'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
                ),
              ],
            ),
    );
  }

  // Un ejercicio de la rutina: asa para arrastrar, nombre, botón de quitar y series y repeticiones.
  // La key tiene que ser única para que Flutter sepa qué ejercicio se ha movido
  Widget _buildRow(int index) {
    final row = _rows[index];

    return Card(
      key: ValueKey(row.exercise.id),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
                const SizedBox(width: 12),
                Expanded(child: Text(row.exercise.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  tooltip: 'Quitar',
                  onPressed: () => setState(() => _rows.removeAt(index)),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCounter('Series', row.sets, (value) => setState(() => row.sets = value)),
                _buildCounter('Reps', row.reps, (value) => setState(() => row.reps = value)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Un contador con botones - y +. El mínimo es 1, que es lo que acepta la API
  Widget _buildCounter(String label, int value, void Function(int) onChanged) {
    return Row(
      children: [
        Text(label),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
        ),
        Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => onChanged(value + 1)),
      ],
    );
  }
}
