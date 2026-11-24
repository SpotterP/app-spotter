import 'package:flutter_test/flutter_test.dart';
import 'package:app_spotter/utils/initials.dart';

// Iniciales del avatar: lo normal, y también los nombres que no empiezan por una letra
void main() {
  test('nombre y apellido dan dos iniciales en mayúscula', () {
    expect(initialsOf('Ana Pérez'), 'AP');
    expect(initialsOf('ana pérez'), 'AP');
  });

  test('un solo nombre da una sola inicial', () {
    expect(initialsOf('Ana'), 'A');
  });

  test('los espacios de más no cuentan como palabras', () {
    expect(initialsOf('   Ana    Pérez   '), 'AP');
  });

  test('un nombre que empieza por emoji usa la letra, no el emoji', () {
    // Cortar la cadena por posiciones partiría el emoji en dos y dejaría un carácter roto
    expect(initialsOf('🚀 Ana'), 'A');
    expect(initialsOf('🚀Ana Pérez'), 'AP');
  });

  test('un nombre sin ninguna letra deja el interrogante', () {
    expect(initialsOf('🚀'), '?');
    expect(initialsOf('   '), '?');
    expect(initialsOf(''), '?');
  });

  test('las letras con tilde y de otros alfabetos también valen', () {
    expect(initialsOf('élena müller'), 'ÉM');
    expect(initialsOf('Ελένη Παπά'), 'ΕΠ');
  });
}
