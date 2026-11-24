import 'package:flutter_test/flutter_test.dart';
import 'package:app_spotter/models/progress.dart';

// Tests sencillos de los modelos del progreso, con el JSON tal y como lo manda la API
void main() {
  test('Progress.fromJson lee el resumen', () {
    final progress = Progress.fromJson({
      'totalSessions': 3,
      'trainedDays': ['2026-11-10', '2026-11-12'],
      'exercises': [
        {'exercise': {'_id': '1', 'name': 'Press banca'}, 'timesDone': 2},
      ],
    });

    expect(progress.totalSessions, 3);
    expect(progress.trainedDays, ['2026-11-10', '2026-11-12']);
    expect(progress.exercises.first.name, 'Press banca');
    expect(progress.exercises.first.timesDone, 2);
  });

  test('TrainingSession.fromJson lee un entrenamiento con rutina', () {
    final session = TrainingSession.fromJson({
      '_id': 's1',
      'workout': 'w1',
      'startedAt': '2026-11-10T10:00:00.000Z',
      'exercises': [
        {
          'exercise': {'_id': '1', 'name': 'Sentadilla'},
          'sets': [
            {'reps': 10, 'weight': 60},
            {'reps': 8, 'weight': 70.5},
          ],
        },
        // Un ejercicio que ya no existe en el catálogo llega como null y se salta
        {'exercise': null, 'sets': []},
      ],
    });

    expect(session.workoutId, 'w1');
    expect(session.exercises.length, 1);
    expect(session.exercises.first.sets.length, 2);
    expect(session.exercises.first.sets[1].weight, 70.5);
  });

  test('un entrenamiento sin rutina tiene workoutId null', () {
    final session = TrainingSession.fromJson({'_id': 's2', 'startedAt': '2026-11-10T10:00:00.000Z', 'exercises': []});

    expect(session.workoutId, null);
  });

  test('formatDay pasa AAAA-MM-DD a día/mes/año', () {
    expect(formatDay('2026-03-05'), '5/3/2026');
  });
}
