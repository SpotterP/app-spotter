import 'package:flutter/foundation.dart';

// Calcula la URL de la API (backend-spotter, puerto 1337 por defecto) según la plataforma.
class Environment {
  // Se puede cambiar al arrancar: flutter run --dart-define=API_URL=http://192.168.1.10:1337
  // El build de release de GitHub pasa la URL de producción desde la variable del repo API_URL.
  static const String _envApiUrl = String.fromEnvironment('API_URL');

  static String get apiUrl => normalizeUrl(_envApiUrl.isNotEmpty ? _envApiUrl : _defaultUrl);

  // Lo que se usa en desarrollo, cuando nadie pasó API_URL.
  static String get _defaultUrl {
    // En el emulador de Android, localhost es el propio móvil,
    // por eso se usa 10.0.2.2 para llegar al ordenador.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:1337';
    }
    // iOS, web y escritorio
    return 'http://localhost:1337';
  }

  // Quita las barras finales: el cliente arma '<base><path>' y el path ya empieza en barra,
  // así que una base acabada en barra pediría 'https://api.tudominio.com//auth'.
  @visibleForTesting
  static String normalizeUrl(String url) => url.replaceAll(RegExp(r'/+$'), '');
}
