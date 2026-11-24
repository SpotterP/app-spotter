import 'package:app_spotter/models/progress.dart';
import 'package:flutter_test/flutter_test.dart';

// El backend agrupa los días entrenados en UTC (toISOString().slice(0, 10)), pero la lista de
// entrenamientos se enseña en hora local. Cerca de medianoche los dos números no cuadran:
// una sesión puede caer en un día en el calendario y en otro en la lista.
// La app calcula los días entrenados en local con las sesiones que ya tiene cargadas, así el
// calendario y la lista dicen siempre el mismo día. Los totales (número de entrenamientos,
// ejercicios) siguen viniendo de GET /users/me/progress.
//
// Todos los instantes de este fichero se construyen desde una hora LOCAL explícita y se mandan
// a la API en UTC, así que las comprobaciones valen en cualquier zona horaria.
void main() {
  // Un entrenamiento hecho a la hora local indicada:
  // se manda como lo manda el backend (UTC) y se lee como lo lee la app (TrainingSession.fromJson).
  TrainingSession sessionAt(String id, DateTime local) => TrainingSession.fromJson({
        '_id': id,
        'startedAt': local.toUtc().toIso8601String(),
        'exercises': [],
      });

  test('una sesión a las 23:30 hora local cae en su día local, no en el día UTC', () {
    // Las 23:30 del 5 de marzo, en la zona horaria del que ejecuta el test
    final session = sessionAt('s1', DateTime(2026, 3, 5, 23, 30));

    expect(localTrainedDays([session]), ['2026-03-05']);
  });

  test('una sesión de madrugada cae en su día local aunque en UTC sea el día anterior', () {
    // A las 00:30 locales del 6 de marzo, en una zona por delante de UTC el instante UTC
    // todavía es el 5 de marzo. El día que se pinta es el local, que es el que ve el usuario.
    final session = sessionAt('s1', DateTime(2026, 3, 6, 0, 30));

    expect(session.startedAt, DateTime(2026, 3, 6, 0, 30));
    expect(localTrainedDays([session]), ['2026-03-06']);
  });

  test('dos sesiones del mismo día local cuentan como un solo día entrenado', () {
    final morning = sessionAt('s1', DateTime(2026, 3, 5, 8));
    final night = sessionAt('s2', DateTime(2026, 3, 5, 23, 30));

    expect(localTrainedDays([morning, night]), ['2026-03-05']);
  });

  test('los días entrenados salen ordenados y sin repetir', () {
    final sessions = [
      sessionAt('s1', DateTime(2026, 3, 7, 9)),
      sessionAt('s2', DateTime(2026, 3, 5, 23, 30)),
      sessionAt('s3', DateTime(2026, 3, 5, 7)),
      sessionAt('s4', DateTime(2026, 3, 6, 0, 30)),
    ];

    expect(localTrainedDays(sessions), ['2026-03-05', '2026-03-06', '2026-03-07']);
  });

  test('una página más de historial alarga los días sin repetir ni perder ninguno', () {
    // Lo que hay cargado tras la primera página
    final firstPage = [sessionAt('s1', DateTime(2026, 3, 5, 23, 30))];
    // Lo que se junta al pulsar «Cargar más»: un día nuevo y otro entrenamiento del día que ya había
    final moreSessions = [
      ...firstPage,
      sessionAt('s2', DateTime(2026, 3, 5, 18)),
      sessionAt('s3', DateTime(2026, 3, 3, 0, 30)),
    ];

    expect(localTrainedDays(firstPage), ['2026-03-05']);
    expect(localTrainedDays(moreSessions), ['2026-03-03', '2026-03-05']);
  });

  test('un historial vacío no da ningún día', () {
    expect(localTrainedDays(const []), isEmpty);
  });

  test('los totales siguen viniendo del resumen de /users/me/progress', () {
    // El resumen que manda el backend: agrupa en UTC, así que la sesión de las 00:30 locales
    // del 6 de marzo cuenta ahí como 5 de marzo. Ese número no lo toca la app.
    final progress = Progress.fromJson({
      'totalSessions': 1,
      'trainedDays': ['2026-03-05'],
      'exercises': [
        {
          'exercise': {'_id': '1', 'name': 'Press banca'},
          'timesDone': 1,
        },
      ],
    });

    final sessions = [sessionAt('s1', DateTime(2026, 3, 6, 0, 30))];

    // El total y los ejercicios vienen del resumen, no de las sesiones cargadas
    expect(progress.totalSessions, 1);
    expect(progress.exercises.single.name, 'Press banca');
    expect(progress.exercises.single.timesDone, 1);
    // Y el día que pinta la app es el local, calculado con las sesiones
    expect(localTrainedDays(sessions), ['2026-03-06']);
  });

  test('el día local se escribe en el mismo formato que manda la API', () {
    expect(localDay(DateTime(2026, 3, 5, 23, 30)), '2026-03-05');
    expect(localDay(DateTime(2026, 11, 9, 0, 30)), '2026-11-09');
  });

  test('el día sale de la hora local aunque el día UTC sea otro', () {
    // El caso de las 23:30 no prueba nada al este de UTC (23:30 en Madrid ya es el mismo día en UTC).
    // Este test elige la hora según el lado del meridiano en el que esté la máquina, para que el día
    // local y el UTC sean días distintos SIEMPRE y el cálculo en UTC falle aquí en cualquier zona.
    final desfase = DateTime.now().timeZoneOffset;
    final local = desfase.isNegative
        // Al oeste de UTC: a esta hora en UTC ya es el día siguiente
        ? DateTime(2026, 3, 5, 23, 30)
        // Al este de UTC: a esta hora en UTC todavía es el día anterior
        : DateTime(2026, 3, 6, 0, 30);

    final sesion = TrainingSession.fromJson({
      '_id': 's1',
      'startedAt': local.toUtc().toIso8601String(),
      'exercises': [],
    });

    expect(localTrainedDays([sesion]), [localDay(local)]);
  }, skip: DateTime.now().timeZoneOffset == Duration.zero ? 'en UTC el día local y el UTC son el mismo' : null);
}
