// Este archivo usa widgets de material.dart, que Flutter 3.50 marca como obsoleto (el mismo aviso que
// tiene el resto de la app). Se silencia aquí para que este test no sume incidencias nuevas.
// ignore_for_file: deprecated_member_use

import 'package:app_spotter/models/progress.dart';
import 'package:app_spotter/models/workout.dart';
import 'package:app_spotter/providers/auth_provider.dart';
import 'package:app_spotter/screens/session_detail_screen.dart';
import 'package:app_spotter/screens/training_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Los pesos se tienen que leer igual en las dos pantallas donde salen: al apuntar una serie durante
// el entrenamiento y en el detalle de un entrenamiento ya guardado. Un peso entero se ve "60 kg",
// nunca "60.0 kg", y uno con decimales se ve tal cual ("12.5 kg").
void main() {
  // El detalle de un entrenamiento con tres series: 60.0 (un entero que llega como decimal), 12.5 y 0
  Widget detail() {
    final session = TrainingSession(
      id: 's1',
      workoutId: null,
      startedAt: DateTime(2026, 3, 5, 10),
      exercises: [
        SessionExercise(name: 'Sentadilla', sets: [
          SessionSet(reps: 10, weight: 60.0),
          SessionSet(reps: 8, weight: 12.5),
          SessionSet(reps: 5, weight: 0),
        ]),
      ],
    );

    return MaterialApp(home: SessionDetailScreen(session: session, routineName: 'Pierna'));
  }

  testWidgets('el detalle de un entrenamiento enseña el peso sin ".0" cuando es entero', (tester) async {
    await tester.pumpWidget(detail());

    expect(find.text('Serie 1: 10 repeticiones con 60 kg'), findsOneWidget);
    expect(find.text('Serie 2: 8 repeticiones con 12.5 kg'), findsOneWidget);
    expect(find.text('Serie 3: 5 repeticiones con 0 kg'), findsOneWidget);
  });

  testWidgets('al apuntar una serie en el entrenamiento el peso se ve igual que en el detalle', (tester) async {
    final workout = Workout(
      id: 'w1',
      name: 'Pierna',
      days: [],
      exercises: [WorkoutExercise(exercise: Exercise(id: 'e1', name: 'Sentadilla'), sets: 3, reps: 10)],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: MaterialApp(home: TrainingSessionScreen(workout: workout)),
      ),
    );

    // Los mismos tres pesos que en el detalle: "60.0", "12,5" (con coma) y "0"
    for (final weight in ['60.0', '12,5', '0']) {
      await tester.enterText(find.byType(TextField).last, weight);
      await tester.tap(find.byTooltip('Añadir serie'));
      await tester.pump();
    }

    expect(find.text('Serie 1: 10 repeticiones con 60 kg'), findsOneWidget);
    expect(find.text('Serie 2: 10 repeticiones con 12.5 kg'), findsOneWidget);
    expect(find.text('Serie 3: 10 repeticiones con 0 kg'), findsOneWidget);
  });
}
