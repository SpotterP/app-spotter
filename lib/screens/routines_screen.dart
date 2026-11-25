import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../models/workout.dart';
import '../providers/auth_provider.dart';
import '../services/http_client.dart';
import '../services/workout_service.dart';
import '../theme/app_colors.dart';
import 'routine_edit_screen.dart';

// Rutinas de mentira. Solo sirven para dibujar el esqueleto mientras llegan las de verdad
final _fakeWorkouts = List.filled(3, Workout(id: '', name: 'Nombre de la rutina', days: [], exercises: []));

// Pestaña "Mis rutinas": lista las rutinas del usuario, permite crear una nueva y borrar las que
// ya no usa. Al tocar una rutina se abre su edición.
class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  // Controla el texto del campo de nueva rutina
  final _nameController = TextEditingController();

  // null mientras se cargan las rutinas
  List<Workout>? _workouts;
  String? _error;
  bool _creating = false;

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

  // Crea una rutina con el nombre escrito (POST /users/me/workouts) y recarga la lista
  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final auth = context.read<AuthProvider>();
    setState(() => _creating = true);

    try {
      await WorkoutService.createMyWorkout(auth, name);
      _nameController.clear();
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }

    if (!mounted) return;
    setState(() => _creating = false);
  }

  // Pide confirmación y, si el usuario acepta, borra la rutina (DELETE /users/me/workouts/:id)
  Future<void> _delete(Workout workout) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar rutina'),
        content: Text('¿Seguro que quieres borrar «${workout.name}»?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final auth = context.read<AuthProvider>();

    try {
      await WorkoutService.deleteMyWorkout(auth, workout.id);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // Abre la pantalla de edición y, al volver, recarga la lista por si se ha cambiado algo
  Future<void> _open(Workout workout) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoutineEditScreen(workoutId: workout.id)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final workouts = _workouts;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis rutinas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Campo y botón para crear una rutina nueva
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nueva rutina', hintText: 'Por ejemplo, Pierna', border: OutlineInputBorder()),
                  onSubmitted: (_) => _create(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(onPressed: _creating ? null : _create, child: Text(_creating ? 'Creando…' : 'Crear')),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.danger)),
          // Sin rutinas enseñamos un mensaje en vez de una lista vacía
          if (workouts != null && workouts.isEmpty) const Center(child: Text('Todavía no tienes rutinas. Crea una para empezar.')),
          // Mientras cargan se pintan 3 rutinas de mentira y Skeletonizer las deja como esqueleto
          if (_error == null)
            Skeletonizer(
              enabled: workouts == null,
              child: Column(
                children: [
                  for (final workout in workouts ?? _fakeWorkouts)
                    Card(
                      child: ListTile(
                        title: Text(workout.name),
                        subtitle: Text(workout.exercises.length == 1 ? '1 ejercicio' : '${workout.exercises.length} ejercicios'),
                        onTap: () => _open(workout),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                          tooltip: 'Borrar',
                          onPressed: () => _delete(workout),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
