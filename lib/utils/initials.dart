// Iniciales del nombre para el círculo del avatar ("Ana Pérez" -> "AP").
// Vive aquí y no dentro de la pantalla para poder probarlo sin montar la pantalla.
library;

// Una letra de cualquier alfabeto. Se compara letra a letra en vez de cortar la cadena por
// posiciones: un emoji ocupa dos posiciones en una cadena de Dart, así que cortarlo por la
// mitad deja un carácter roto en pantalla.
final _letra = RegExp(r'^\p{L}', unicode: true);

// La primera letra del nombre: la de la primera palabra que tenga alguna letra, y si hay más,
// la de la siguiente. Devuelve '?' cuando no hay ninguna (un nombre vacío o sólo de símbolos).
String initialsOf(String name) {
  final palabras = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);

  final iniciales = <String>[];
  for (final palabra in palabras) {
    final inicial = _primeraLetra(palabra);
    if (inicial.isEmpty) continue;

    iniciales.add(inicial);
    if (iniciales.length == 2) break;
  }

  return iniciales.isEmpty ? '?' : iniciales.join();
}

// La primera letra de una palabra, saltando emojis y signos ("🚀ana" -> "A")
String _primeraLetra(String palabra) {
  for (final rune in palabra.runes) {
    final caracter = String.fromCharCode(rune);
    if (_letra.hasMatch(caracter)) return caracter.toUpperCase();
  }

  return '';
}
