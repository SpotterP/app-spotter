import 'package:app_spotter/main.dart';
import 'package:app_spotter/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonizer/skeletonizer.dart';

void main() {
  // GetX guarda su estado en global: se limpia para que un test no afecte al siguiente
  tearDown(Get.reset);

  testWidgets('el arranque muestra el esqueleto, no el circulo girando', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    // Un AuthProvider recién creado está en starting: la sesión guardada se lee en loadSession,
    // que acá no se llama, así que la app se queda en la pantalla de arranque.
    final auth = AuthProvider(httpRequest: (path, {method = 'GET', body, token}) async => null);
    expect(auth.starting, isTrue);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pump();

    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'el arranque no puede mostrar el círculo pelado',
    );
    expect(
      find.byType(StartingSkeleton),
      findsOneWidget,
      reason: 'el arranque muestra el esqueleto de la app',
    );
    // Skeletonizer es abstracto y el constructor devuelve una subclase privada, así que
    // byType no lo encuentra: se busca por tipo con un predicado.
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Skeletonizer && widget.enabled,
        description: 'Skeletonizer activo',
      ),
      findsOneWidget,
      reason: 'el esqueleto se pinta con Skeletonizer, el paquete de las demás pantallas',
    );
  });
}
