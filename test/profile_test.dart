import 'dart:convert';

import 'package:app_spotter/models/user.dart';
import 'package:app_spotter/providers/auth_provider.dart';
import 'package:app_spotter/services/http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// El perfil tiene que enseñar lo que dice la API, no la copia que se guardó en el login.
// La petición se sustituye por una falsa para no salir a la red.
void main() {
  // Lo que quedó guardado en el móvil al iniciar sesión, antes de abrir el perfil
  Map<String, String> savedSession({String name = 'Ana Vieja', String email = 'vieja@example.com', String role = 'USER'}) {
    return {
      'user': jsonEncode({'_id': 'u1', 'name': name, 'email': email, 'role': role}),
    };
  }

  test('loadProfile pide GET /users/me y actualiza lo guardado', () async {
    SharedPreferences.setMockInitialValues(savedSession());

    final called = <String>[];
    String? sentToken;
    final auth = AuthProvider(
      httpRequest: (path, {method = 'GET', body, token}) async {
        called.add('$method $path');
        sentToken = token;
        // GET /users/me devuelve el perfil completo, rol incluido
        return {
          'user': {'_id': 'u1', 'name': 'Ana Nueva', 'email': 'nueva@example.com', 'role': 'ADMIN'},
        };
      },
    );
    auth.user = User.fromJson({'_id': 'u1', 'name': 'Ana Vieja', 'email': 'vieja@example.com', 'role': 'USER'});
    auth.token = 'token-de-prueba';

    await auth.loadProfile();

    // Pide el perfil a la API, con el token de la sesión
    expect(called, ['GET /users/me']);
    expect(sentToken, 'token-de-prueba');
    // Y enseña lo que ha devuelto
    expect(auth.user!.name, 'Ana Nueva');
    expect(auth.user!.email, 'nueva@example.com');
    // El rol sale de la respuesta del perfil y manda sobre el que se guardó en el login
    expect(auth.user!.role, 'ADMIN');
    expect(auth.profileError, isNull);
    expect(auth.profileLoading, isFalse);

    // Y lo guardado en el móvil también queda actualizado, para la próxima vez
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('user')!);
    expect(saved['name'], 'Ana Nueva');
    expect(saved['email'], 'nueva@example.com');
    expect(saved['role'], 'ADMIN');
  });

  test('si la API falla se avisa y se dejan los datos que ya estaban', () async {
    SharedPreferences.setMockInitialValues(savedSession(role: 'ADMIN'));

    String? sentToken;
    final auth = AuthProvider(
      httpRequest: (path, {method = 'GET', body, token}) async {
        sentToken = token;
        throw ApiException('No se puede conectar con la API', 0);
      },
    );
    auth.user = User.fromJson({'_id': 'u1', 'name': 'Ana Vieja', 'email': 'vieja@example.com', 'role': 'ADMIN'});
    auth.token = 'token-de-prueba';

    await auth.loadProfile();

    // Se avisa del problema y no se pierde nada de lo que ya teníamos: nombre, email y rol
    expect(sentToken, 'token-de-prueba');
    expect(auth.profileError, 'No se puede conectar con la API');
    expect(auth.user!.name, 'Ana Vieja');
    expect(auth.user!.email, 'vieja@example.com');
    expect(auth.user!.role, 'ADMIN');
    expect(auth.profileLoading, isFalse);

    // Y lo guardado en el móvil no se toca
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('user')!);
    expect(saved['name'], 'Ana Vieja');
    expect(saved['email'], 'vieja@example.com');
    expect(saved['role'], 'ADMIN');
  });
}
