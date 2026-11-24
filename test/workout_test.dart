import 'package:flutter_test/flutter_test.dart';
import 'package:app_spotter/models/workout.dart';

// Test sencillo del modelo Workout: fromJson con el JSON tal y como lo manda la API
void main() {
  test('Workout.fromJson lee el nombre y los ejercicios', () {
    final workout = Workout.fromJson({
      '_id': 'w1',
      'name': 'Pierna',
      'exercises': [
        {'exercise': {'_id': 'e1', 'name': 'Sentadilla'}, 'sets': 4, 'reps': 10},
        // Un ejercicio que ya no existe en el catálogo llega como null y se salta
        {'exercise': null, 'sets': 3, 'reps': 12},
      ],
    });

    expect(workout.name, 'Pierna');
    expect(workout.exercises.length, 1);
    expect(workout.exercises.first.sets, 4);
    expect(workout.exercises.first.reps, 10);
  });

  test('Exercise.fromJson lee la categoría', () {
    final exercise = Exercise.fromJson({'_id': 'e1', 'name': 'Sentadilla búlgara', 'category': 'LEGS'});

    expect(exercise.name, 'Sentadilla búlgara');
    expect(exercise.category, 'LEGS');
  });
}
