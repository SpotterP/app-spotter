import 'package:flutter_test/flutter_test.dart';
import 'package:app_spotter/models/training.dart';
import 'package:app_spotter/models/workout.dart';

// Tests sencillos de los datos del entrenamiento en curso
void main() {
  test('weekDays va de lunes a domingo con las claves de la API', () {
    expect(weekDays.length, 7);
    expect(weekDays.first, ('MONDAY', 'Lunes'));
    expect(weekDays.last, ('SUNDAY', 'Domingo'));
  });

  test('un ejercicio en curso empieza sin series y guarda lo previsto', () {
    final exercise = ActiveExercise(exercise: Exercise(id: 'e1', name: 'Sentadilla'), plannedSets: 4, plannedReps: 10);

    expect(exercise.sets, isEmpty);
    expect(exercise.plannedSets, 4);

    exercise.sets.add(ActiveSet(reps: 10, weight: 60));
    expect(exercise.sets.length, 1);
  });
}
