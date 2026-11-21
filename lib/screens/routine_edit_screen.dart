import 'package:flutter/material.dart';

// Pantalla provisional para editar una rutina. De momento solo se abre desde Mis rutinas;
// la edición (nombre, ejercicios, series y orden) se añade en otra tarea.
class RoutineEditScreen extends StatelessWidget {
  final String workoutId;

  const RoutineEditScreen({super.key, required this.workoutId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar rutina')),
      body: const Center(child: Text('En desarrollo')),
    );
  }
}
