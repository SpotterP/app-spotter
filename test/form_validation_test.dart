// Este archivo usa widgets de material.dart, que Flutter 3.50 marca como obsoleto (el mismo aviso que
// tiene el resto de la app). Se silencia aquí para que este test no sume incidencias nuevas.
// ignore_for_file: deprecated_member_use

import 'package:app_spotter/providers/auth_provider.dart';
import 'package:app_spotter/screens/login_screen.dart';
import 'package:app_spotter/screens/register_screen.dart';
import 'package:app_spotter/screens/routine_edit_screen.dart';
import 'package:app_spotter/services/http_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Los formularios de login, registro y editar rutina validan el email, la contraseña y los nombres
// con reglas ya hechas (form_builder_validators), con sus mensajes en español. Un email inventado
// como "a@b" no vale, y si algo falta, el propio campo lo dice y no se llama a la API.
// La petición se sustituye por una falsa para no salir a la red.
void main() {
  // Una cuenta de usuario, como la que devuelve la API al entrar
  final loginResponse = {
    'token': 'token-ana',
    'refreshToken': 'refresh-ana',
    'user': {'_id': 'u1', 'name': 'Ana', 'email': 'ana@example.com', 'role': 'USER'},
  };

  // La rutina "Pierna" con un ejercicio, tal y como la manda GET /users/me/workouts/:id
  final workoutResponse = {
    'workout': {
      '_id': 'w1',
      'name': 'Pierna',
      'days': <String>[],
      'exercises': [
        {
          'exercise': {'_id': 'e1', 'name': 'Sentadilla', 'category': 'LEGS'},
          'sets': 4,
          'reps': 10,
        },
      ],
    },
  };

  // Un AuthProvider cuya API es falsa: apunta cada petición en "called" y contesta lo que toque
  AuthProvider fakeAuth(List<String> called, [List<Map<String, dynamic>?>? bodies]) {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    return AuthProvider(httpRequest: (path, {method = 'GET', body, token}) async {
      called.add('$method $path');
      bodies?.add(body);
      if (path == '/auth/login') return loginResponse;
      if (path == '/users/me/workouts/w1') return workoutResponse;
      return null;
    });
  }

  Future<void> open(WidgetTester tester, AuthProvider auth, Widget screen) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(value: auth, child: MaterialApp(home: screen)),
    );
    await tester.pumpAndSettle();
  }

  // Escribe en el campo que lleva esa etiqueta
  Future<void> type(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
  }

  // Pulsa el botón con ese texto (el título de la pantalla puede llamarse igual) y espera a que se repinte
  Future<void> tap(WidgetTester tester, String label) async {
    final button = find.widgetWithText(FilledButton, label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('login', () {
    testWidgets('un email inventado no vale y no se llama a la API', (tester) async {
      final called = <String>[];
      await open(tester, fakeAuth(called), const LoginScreen());

      // "a@b" tiene arroba pero no es un email: antes pasaba, ahora no
      for (final email in ['a@b', 'ana', 'ana@', '@example.com', 'ana@example', 'ana @example.com', '']) {
        await type(tester, 'Email', email);
        await type(tester, 'Contraseña', 'secreta');
        await tap(tester, 'Iniciar sesión');

        expect(find.text('Escribe un email válido'), findsOneWidget, reason: 'el email "$email" no debería valer');
      }
      expect(called, isEmpty);
    });

    testWidgets('un email de verdad vale, también con espacios a los lados', (tester) async {
      final called = <String>[];
      final bodies = <Map<String, dynamic>?>[];
      await open(tester, fakeAuth(called, bodies), const LoginScreen());

      await type(tester, 'Email', '  ana@example.com  ');
      await type(tester, 'Contraseña', 'secreta');
      await tap(tester, 'Iniciar sesión');

      expect(find.text('Escribe un email válido'), findsNothing);
      expect(called, ['POST /auth/login']);
      // A la API le llega el email sin los espacios
      expect(bodies.single!['email'], 'ana@example.com');
    });

    testWidgets('sin contraseña lo dice, y con una corta no se queja porque al entrar solo se pide que exista', (tester) async {
      final called = <String>[];
      await open(tester, fakeAuth(called), const LoginScreen());

      await type(tester, 'Email', 'ana@example.com');
      await tap(tester, 'Iniciar sesión');
      expect(find.text('Escribe la contraseña'), findsOneWidget);
      expect(called, isEmpty);

      await type(tester, 'Contraseña', '123');
      await tap(tester, 'Iniciar sesión');
      expect(find.text('Escribe la contraseña'), findsNothing);
      expect(called, ['POST /auth/login']);
    });
  });

  group('registro', () {
    testWidgets('cada campo dice qué falta', (tester) async {
      final auth = fakeAuth([]);
      await open(tester, auth, const RegisterScreen());

      // Todo vacío: los tres avisos a la vez
      await tap(tester, 'Crear cuenta');
      expect(find.text('Escribe tu nombre'), findsOneWidget);
      expect(find.text('Escribe un email válido'), findsOneWidget);
      expect(find.text('Mínimo 8 caracteres'), findsOneWidget);

      // Un nombre que solo tiene espacios tampoco vale (el backend lo recorta con trim)
      await type(tester, 'Nombre', '    ');
      await type(tester, 'Email', 'a@b');
      await type(tester, 'Contraseña', '1234567');
      await tap(tester, 'Crear cuenta');
      expect(find.text('Escribe tu nombre'), findsOneWidget);
      expect(find.text('Escribe un email válido'), findsOneWidget);
      expect(find.text('Mínimo 8 caracteres'), findsOneWidget);

      // Nada de esto ha llegado a la API
      expect(auth.error, isNull);
    });

    testWidgets('con los datos bien no sale ningún aviso y se intenta crear la cuenta', (tester) async {
      // La API de este test falla al crear la cuenta, como si no hubiera conexión
      final called = <String>[];
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final auth = AuthProvider(httpRequest: (path, {method = 'GET', body, token}) async {
        called.add('$method $path');
        throw ApiException('sin conexión', 0);
      });
      await open(tester, auth, const RegisterScreen());

      await type(tester, 'Nombre', 'Ana');
      await type(tester, 'Email', 'ana@example.com');
      // 8 caracteres justos: es el mínimo que exige el backend. Y se repite igual, como pide el formulario
      await type(tester, 'Contraseña', '12345678');
      await type(tester, 'Repite la contraseña', '12345678');
      await tap(tester, 'Crear cuenta');

      expect(find.text('Escribe tu nombre'), findsNothing);
      expect(find.text('Escribe un email válido'), findsNothing);
      expect(find.text('Mínimo 8 caracteres'), findsNothing);
      // La cuenta se ha intentado crear, y como la API falla se ve el error
      expect(called, ['POST /auth/register']);
      expect(auth.error, 'sin conexión');
    });
  });

  group('editar rutina', () {
    testWidgets('sin nombre el campo dice qué falta y no se guarda nada', (tester) async {
      final called = <String>[];
      await open(tester, fakeAuth(called), const RoutineEditScreen(workoutId: 'w1'));
      called.clear();

      // Un nombre vacío y uno hecho solo de espacios valen lo mismo: nada
      for (final name in ['', '    ']) {
        await type(tester, 'Nombre', name);
        await tap(tester, 'Guardar cambios');

        expect(find.text('Escribe el nombre de la rutina'), findsOneWidget, reason: 'el nombre "$name" no debería valer');
      }
      expect(called, isEmpty);
    });

    testWidgets('con nombre se guarda, sin los espacios de los lados', (tester) async {
      final called = <String>[];
      final bodies = <Map<String, dynamic>?>[];
      await open(tester, fakeAuth(called, bodies), const RoutineEditScreen(workoutId: 'w1'));
      called.clear();
      bodies.clear();

      await type(tester, 'Nombre', '  Pierna pesada  ');
      await tap(tester, 'Guardar cambios');

      expect(find.text('Escribe el nombre de la rutina'), findsNothing);
      expect(called, ['PUT /users/me/workouts/w1']);
      expect(bodies.single!['name'], 'Pierna pesada');
    });
  });
}
