// Este archivo usa widgets de material.dart, que Flutter 3.50 marca como obsoleto (el mismo aviso que
// tiene el resto de la app). Se silencia aquí para que este test no sume incidencias nuevas.
// ignore_for_file: deprecated_member_use

import 'package:app_spotter/providers/auth_provider.dart';
import 'package:app_spotter/screens/register_screen.dart';
import 'package:app_spotter/services/http_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:regex_ui/regex_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Al crear una cuenta, la app ayuda a elegir una contraseña segura: dice al momento si es débil, media
// o fuerte y qué le falta, y pide repetirla. Es solo una ayuda: lo único que impide enviar el formulario
// es tener menos de 8 caracteres, que es lo que exige el backend.
// La petición se sustituye por una falsa para no salir a la red.
void main() {
  // Contraseñas de ejemplo, cada una con el nivel que da el indicador
  const debil = 'abc';
  const media = 'Hello2026x';
  const fuerte = 'Zebra-lluvia-9';

  setUpAll(() {
    // Los textos del indicador, en español, como los pone main.dart al arrancar la app
    RegexLabels.current = RegexLabels.es;
  });

  // GetX guarda su estado en global (rutas, avisos): se limpia para que un test no afecte al siguiente
  tearDown(Get.reset);

  // Un AuthProvider cuya API es falsa: apunta cada petición en "called" y, si se le pide, falla con un error
  AuthProvider fakeAuth(List<String> called, {List<Map<String, dynamic>?>? bodies, ApiException? fails}) {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    return AuthProvider(httpRequest: (path, {method = 'GET', body, token}) async {
      called.add('$method $path');
      bodies?.add(body);
      if (fails != null) throw fails;
      return null;
    });
  }

  // La pantalla de crear cuenta se abre desde otra, como en la app, porque al terminar vuelve atrás (Get.back)
  Future<void> open(WidgetTester tester, AuthProvider auth) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: GetMaterialApp(
          home: Scaffold(
            body: Center(child: TextButton(onPressed: () => Get.to(() => const RegisterScreen()), child: const Text('abrir'))),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
    // Se espera a que terminen las animaciones del indicador (las marcas cambian con un fundido)
    await tester.pumpAndSettle();
  }

  // Rellena todo el formulario con datos buenos, menos lo que se indique
  Future<void> fill(WidgetTester tester, {String password = fuerte, String? confirm}) async {
    await type(tester, 'Nombre', 'Ana');
    await type(tester, 'Email', 'ana@example.com');
    await type(tester, 'Contraseña', password);
    await type(tester, 'Repite la contraseña', confirm ?? password);
  }

  // Deja pasar el aviso "Cuenta creada" (se quita solo a los 3 segundos) para que no quede nada pendiente
  Future<void> letNoticeGo(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Crear cuenta');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  // ¿Está cumplida esa regla de la lista? Cada regla es una fila con su texto y una marca (check o cruz)
  bool met(WidgetTester tester, String rule) {
    final row = find.ancestor(of: find.text(rule), matching: find.byType(Row)).first;
    final hasCheck = find.descendant(of: row, matching: find.byIcon(Icons.check_rounded)).evaluate().isNotEmpty;
    final hasCross = find.descendant(of: row, matching: find.byIcon(Icons.close_rounded)).evaluate().isNotEmpty;
    expect(hasCheck != hasCross, isTrue, reason: 'la regla "$rule" debería tener una marca, y solo una');
    return hasCheck;
  }

  // El nivel que enseña ahora el indicador
  String? level(WidgetTester tester) {
    for (final word in ['Débil', 'Media', 'Fuerte']) {
      if (find.text(word).evaluate().isNotEmpty) return word;
    }
    return null;
  }

  group('indicador de fortaleza', () {
    testWidgets('dice al momento si es débil, media o fuerte', (tester) async {
      await open(tester, fakeAuth([]));

      await type(tester, 'Contraseña', debil);
      expect(level(tester), 'Débil');

      await type(tester, 'Contraseña', media);
      expect(level(tester), 'Media');

      await type(tester, 'Contraseña', fuerte);
      expect(level(tester), 'Fuerte');

      // Y vuelve atrás si se borra: se actualiza en los dos sentidos
      await type(tester, 'Contraseña', debil);
      expect(level(tester), 'Débil');
    });

    testWidgets('se actualiza con cada carácter, sin enviar el formulario', (tester) async {
      final called = <String>[];
      await open(tester, fakeAuth(called));

      // Se escribe la contraseña fuerte letra a letra y se apunta el nivel tras cada una
      final niveles = <String?>[];
      for (var i = 1; i <= fuerte.length; i++) {
        await type(tester, 'Contraseña', fuerte.substring(0, i));
        niveles.add(level(tester));
      }

      // Siempre hay un nivel a la vista, empieza débil y termina fuerte
      expect(niveles, everyElement(isNotNull));
      expect(niveles.first, 'Débil');
      expect(niveles.last, 'Fuerte');
      // Todo esto sin enviar nada
      expect(called, isEmpty);
    });

    testWidgets('nombra en concreto lo que le falta, sin mensajes genéricos', (tester) async {
      await open(tester, fakeAuth([]));

      // "abc" solo tiene minúsculas: le faltan caracteres, una mayúscula, un número y un símbolo
      await type(tester, 'Contraseña', debil);
      expect(met(tester, 'Al menos 8 caracteres'), isFalse);
      expect(met(tester, 'Una letra mayúscula'), isFalse);
      expect(met(tester, 'Una letra minúscula'), isTrue);
      expect(met(tester, 'Un número'), isFalse);
      expect(met(tester, 'Un carácter especial'), isFalse);

      // Nada de "contraseña no válida" ni parecidos
      expect(find.textContaining('no válida'), findsNothing);
      expect(find.textContaining('inválida'), findsNothing);

      // Con una fuerte, lo cumple todo
      await type(tester, 'Contraseña', fuerte);
      for (final regla in ['Al menos 8 caracteres', 'Una letra mayúscula', 'Una letra minúscula', 'Un número', 'Un carácter especial']) {
        expect(met(tester, regla), isTrue, reason: 'con "$fuerte" debería cumplir "$regla"');
      }
    });
  });

  group('enviar el formulario', () {
    testWidgets('una contraseña de menos de 8 caracteres no se envía y dice que faltan caracteres', (tester) async {
      final called = <String>[];
      await open(tester, fakeAuth(called));

      await fill(tester, password: 'Ab1!');
      await submit(tester);

      expect(find.text('Mínimo 8 caracteres'), findsOneWidget);
      expect(called, isEmpty);
    });

    testWidgets('una contraseña débil de 8 o más caracteres sí se envía: el indicador ayuda, no bloquea', (tester) async {
      final called = <String>[];
      await open(tester, fakeAuth(called));

      await fill(tester, password: 'abcdefgh');
      expect(level(tester), 'Débil');
      await submit(tester);

      expect(called, ['POST /auth/register']);

      await letNoticeGo(tester);
    });

    testWidgets('una contraseña fuerte se acepta: se crea la cuenta y se vuelve atrás', (tester) async {
      final called = <String>[];
      final bodies = <Map<String, dynamic>?>[];
      await open(tester, fakeAuth(called, bodies: bodies));

      await fill(tester);
      await submit(tester);

      expect(called, ['POST /auth/register']);
      // A la API le llega una sola contraseña, la que se escribió
      expect(bodies.single, {'name': 'Ana', 'email': 'ana@example.com', 'password': fuerte});
      // Se ha vuelto a la pantalla de antes y se avisa
      expect(find.byType(RegisterScreen), findsNothing);
      expect(find.text('Cuenta creada'), findsOneWidget);

      await letNoticeGo(tester);
    });
  });

  group('repetir la contraseña', () {
    testWidgets('si no coinciden no se envía y lo dice', (tester) async {
      final called = <String>[];
      await open(tester, fakeAuth(called));

      await fill(tester, confirm: 'Zebra-lluvia-8');
      await submit(tester);

      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
      expect(called, isEmpty);
    });

    testWidgets('si se deja vacío tampoco se envía', (tester) async {
      final called = <String>[];
      await open(tester, fakeAuth(called));

      await fill(tester, confirm: '');
      await submit(tester);

      expect(find.text('Campo obligatorio'), findsOneWidget);
      expect(called, isEmpty);
    });

    testWidgets('si coinciden se puede crear la cuenta', (tester) async {
      final called = <String>[];
      await open(tester, fakeAuth(called));

      await fill(tester);
      await submit(tester);

      expect(find.text('Las contraseñas no coinciden'), findsNothing);
      expect(called, ['POST /auth/register']);

      await letNoticeGo(tester);
    });
  });

  group('si la API rechaza la contraseña', () {
    testWidgets('el motivo sale junto al campo de la contraseña y la cuenta no se crea', (tester) async {
      final called = <String>[];
      final motivo = ApiException('"password" length must be at least 8 characters long', 422);
      await open(tester, fakeAuth(called, fails: motivo));

      await fill(tester);
      await submit(tester);

      // Se ha intentado, y el motivo que devuelve la API se ve en pantalla (una sola vez, en el campo)
      expect(called, ['POST /auth/register']);
      expect(find.text(motivo.message), findsOneWidget);
      // No se ha creado la cuenta: seguimos en la pantalla y no hay aviso de éxito
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('Cuenta creada'), findsNothing);

      // Al volver a escribir la contraseña, el motivo viejo desaparece
      await type(tester, 'Contraseña', 'otra-Distinta-1');
      expect(find.text(motivo.message), findsNothing);
    });

    testWidgets('un error que no es de la contraseña sale abajo, no junto a su campo', (tester) async {
      final auth = fakeAuth([], fails: ApiException('email ya existe', 409));
      await open(tester, auth);

      await fill(tester);
      await submit(tester);

      expect(find.text('email ya existe'), findsOneWidget);
      expect(auth.passwordError, isNull);
      expect(auth.error, 'email ya existe');
    });
  });
}
