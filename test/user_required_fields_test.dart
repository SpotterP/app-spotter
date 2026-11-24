import 'dart:convert';

import 'package:app_spotter/models/user.dart';
import 'package:app_spotter/providers/auth_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Si la API deja de mandar un campo del usuario, la app lo dice claro en vez de enseñar el
// hueco o un rol inventado. _id, name y email son obligatorios; role es opcional.
void main() {
  const storage = FlutterSecureStorage();

  // Lo que tiene que hacer el modelo cuando falta un campo obligatorio
  Matcher fallaPorFaltaDe(String campo) => throwsA(
        isA<FormatException>().having((e) => e.message.toString(), 'mensaje', contains(campo)),
      );

  group('el modelo no tapa un campo que falta', () {
    test('el camino bueno sigue pasando', () {
      final user = User.fromJson({'_id': '1', 'name': 'Ana', 'email': 'ana@example.com', 'role': 'USER'});

      expect(user.id, '1');
      expect(user.name, 'Ana');
      expect(user.email, 'ana@example.com');
      expect(user.role, 'USER');
    });

    test('sin email falla y lo nombra', () {
      expect(() => User.fromJson({'_id': '1', 'name': 'Ana'}), fallaPorFaltaDe('email'));
    });

    test('sin name falla y lo nombra', () {
      expect(() => User.fromJson({'_id': '1', 'email': 'ana@example.com'}), fallaPorFaltaDe('name'));
    });

    test('sin _id falla y lo nombra', () {
      expect(() => User.fromJson({'name': 'Ana', 'email': 'ana@example.com'}), fallaPorFaltaDe('_id'));
    });

    test('el rol es opcional y sin él se queda USER', () {
      final user = User.fromJson({'_id': '1', 'name': 'Ana', 'email': 'ana@example.com'});

      expect(user.role, 'USER');
    });

    test('un campo vacío o de otro tipo también se rechaza', () {
      // "Presente pero inservible" es peor que ausente: se ve un hueco igual
      expect(() => User.fromJson({'_id': '', 'name': 'Ana', 'email': 'ana@example.com'}), fallaPorFaltaDe('_id'));
      expect(() => User.fromJson({'_id': '1', 'name': 5, 'email': 'ana@example.com'}), fallaPorFaltaDe('name'));
    });
  });

  group('la app enseña el error en vez de quedarse a medias', () {
    test('un login con el usuario incompleto avisa y no guarda nada', () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});

      final auth = AuthProvider(
        httpRequest: (path, {method = 'GET', body, token}) async {
          if (path == '/auth/login') {
            return {
              'token': 'token',
              'refreshToken': 'refresh',
              // Falta el email
              'user': {'_id': 'u1', 'name': 'Ana', 'role': 'USER'},
            };
          }
          return null;
        },
      );

      final entro = await auth.login('ana@example.com', 'secreta');

      expect(entro, isFalse);
      expect(auth.error, contains('email'));
      expect(auth.loading, isFalse);
      expect(auth.token, isNull);
      expect(auth.user, isNull);
      expect(await storage.read(key: 'token'), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user'), isNull);
    });

    test('un login incompleto tampoco guarda el refresh token', () async {
      // El refresh token es el que dura 7 días: si el login no vale, no puede quedar guardado
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});

      final auth = AuthProvider(
        httpRequest: (path, {method = 'GET', body, token}) async {
          if (path == '/auth/login') {
            return {
              'token': 'token',
              'refreshToken': 'refresh',
              'user': {'_id': 'u1', 'name': 'Ana'},
            };
          }
          return null;
        },
      );

      expect(await auth.login('ana@example.com', 'secreta'), isFalse);

      expect(auth.refreshToken, isNull);
      expect(await storage.read(key: 'refreshToken'), isNull);
    });

    test('un perfil incompleto avisa y deja la sesión como estaba', () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({'token': 'token', 'refreshToken': 'refresh'});

      final auth = AuthProvider(
        httpRequest: (path, {method = 'GET', body, token}) async {
          // GET /users/me sin el nombre
          return {
            'user': {'_id': 'u1', 'email': 'ana@example.com', 'role': 'USER'},
          };
        },
      );
      auth.user = User.fromJson({'_id': 'u1', 'name': 'Ana', 'email': 'ana@example.com', 'role': 'USER'});
      auth.token = 'token';
      auth.refreshToken = 'refresh';

      await auth.loadProfile();

      expect(auth.profileError, contains('name'));
      expect(auth.profileLoading, isFalse);
      // La sesión sigue abierta: el perfil no se ha podido refrescar, pero no se ha perdido
      expect(auth.user!.name, 'Ana');
      expect(auth.token, 'token');
    });

    test('una sesión guardada incompleta no cuelga el arranque', () async {
      // Un 'user' guardado por una versión anterior o tocado a mano: mejor empezar de cero
      SharedPreferences.setMockInitialValues({
        'user': jsonEncode({'_id': 'u1', 'name': 'Ana'}),
      });
      FlutterSecureStorage.setMockInitialValues({'token': 'token', 'refreshToken': 'refresh'});

      final auth = AuthProvider(
        httpRequest: (path, {method = 'GET', body, token}) async => null,
      );

      await auth.loadSession();

      expect(auth.starting, isFalse);
      expect(auth.isLoggedIn, isFalse);
      expect(auth.user, isNull);
      expect(await storage.read(key: 'token'), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user'), isNull);
    });
  });
}
