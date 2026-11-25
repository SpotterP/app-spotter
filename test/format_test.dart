import 'package:app_spotter/models/progress.dart';
import 'package:flutter_test/flutter_test.dart';

// Tests sencillos de cómo se enseñan los pesos y las fechas, que es igual en toda la app
void main() {
  group('formatWeight', () {
    test('un peso entero se ve sin decimales, venga como entero o como decimal', () {
      expect(formatWeight(60), '60');
      expect(formatWeight(60.0), '60');
      expect(formatWeight(0), '0');
      expect(formatWeight(100.0), '100');
    });

    test('un peso con decimales se ve tal cual', () {
      expect(formatWeight(12.5), '12.5');
      expect(formatWeight(0.5), '0.5');
      expect(formatWeight(62.25), '62.25');
    });

    test('se enseñan 2 decimales como máximo', () {
      expect(formatWeight(12.349), '12.35');
    });

    test('los pesos grandes no llevan separador de miles', () {
      expect(formatWeight(1000), '1000');
    });
  });

  group('formatDate', () {
    test('día/mes/año, sin ceros delante', () {
      expect(formatDate(DateTime(2026, 3, 5)), '5/3/2026');
      expect(formatDate(DateTime(2026, 11, 25)), '25/11/2026');
    });

    test('la hora no cambia el día que se enseña', () {
      expect(formatDate(DateTime(2026, 3, 5, 23, 59)), '5/3/2026');
      expect(formatDate(DateTime(2026, 3, 5, 0, 1)), '5/3/2026');
    });
  });
}
