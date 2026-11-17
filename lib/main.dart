import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'theme/app_colors.dart';

// Punto de entrada de la app. main() es lo primero que se ejecuta y runApp() pinta el widget raíz.
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ChangeNotifierProvider deja el AuthProvider disponible para toda la app.
    // Los ".." llaman a loadSession nada más crearlo, para leer la sesión guardada.
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..loadSession(),
      // GetMaterialApp = MaterialApp de GetX. Añade las rutas con nombre
      child: GetMaterialApp(
        title: 'Spotter',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: AppColors.primary,
          scaffoldBackgroundColor: AppColors.background,
        ),
        // Pantalla de inicio: depende de si hay sesión o no
        home: const AuthGate(),
        getPages: [
          GetPage(name: '/register', page: () => const RegisterScreen()),
        ],
      ),
    );
  }
}

// Decide qué pantalla enseñar: cargando, login (sin sesión) o principal (con sesión).
// Como escucha al AuthProvider, cambia sola al hacer login o logout.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.starting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return auth.isLoggedIn ? const HomeScreen() : const LoginScreen();
  }
}
