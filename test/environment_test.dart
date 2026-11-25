import 'package:app_spotter/config/environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Environment.normalizeUrl', () {
    test('una barra final no deja rutas con doble barra', () {
      // http_client arma la URL como '<base><path>' y el path ya empieza en barra,
      // así que una base con barra final pediría 'https://api.tudominio.com//auth'.
      expect(Environment.normalizeUrl('https://api.tudominio.com/'), 'https://api.tudominio.com');
      expect(Environment.normalizeUrl('https://api.tudominio.com///'), 'https://api.tudominio.com');
    });

    test('una URL sin barra final queda igual', () {
      expect(Environment.normalizeUrl('https://api.tudominio.com'), 'https://api.tudominio.com');
      expect(Environment.normalizeUrl('http://192.168.1.10:1337'), 'http://192.168.1.10:1337');
    });

    test('una cadena vacía sigue vacía', () {
      expect(Environment.normalizeUrl(''), '');
    });
  });
}
