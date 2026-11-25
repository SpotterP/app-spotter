import 'package:flutter/material.dart';

import '../models/progress.dart';

// Detalle de un entrenamiento: sus ejercicios con las series que se hicieron.
// Recibe el entrenamiento ya cargado, porque la lista de la API ya trae los ejercicios y las series.
class SessionDetailScreen extends StatelessWidget {
  final TrainingSession session;
  final String routineName;

  const SessionDetailScreen({super.key, required this.session, required this.routineName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(routineName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(formatDate(session.startedAt), style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          if (session.exercises.isEmpty) const Text('Este entrenamiento no tiene ejercicios'),
          for (final exercise in session.exercises)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    // Una línea por serie: "Serie 1: 10 repeticiones con 60 kg"
                    for (var i = 0; i < exercise.sets.length; i++)
                      Text('Serie ${i + 1}: ${exercise.sets[i].reps} repeticiones con ${formatWeight(exercise.sets[i].weight)} kg'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
