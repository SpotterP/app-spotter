import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:regex_ui/regex_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'theme/app_colors.dart';

// Punto de entrada de la app. main() es lo primero que se ejecuta y runApp() pinta el widget raíz.
void main() {
  // Los textos que escribe regex_ui solo (el indicador de la contraseña) salen en español
  RegexLabels.current = RegexLabels.es;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider deja disponibles para toda la app el AuthProvider (la sesión) y el ThemeProvider
    // (el tema elegido). Los ".." llaman a loadSession y loadTheme nada más crearlos, para leer
    // lo que se guardó la última vez.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..loadSession()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadTheme()),
      ],
      // Consumer vuelve a pintar la app cada vez que el usuario cambia de tema
      child: Consumer<ThemeProvider>(
        // GetMaterialApp = MaterialApp de GetX. Añade las rutas con nombre
        builder: (_, themeProvider, __) => GetMaterialApp(
          title: 'Spotter',
          debugShowCheckedModeBanner: false,
          // Tema claro y tema oscuro. themeMode dice cuál se usa: el elegido o el del móvil
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: AppColors.primary,
            scaffoldBackgroundColor: AppColors.background,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: AppColors.primary,
            brightness: Brightness.dark,
          ),
          themeMode: themeProvider.mode,
          // Le dice a Skeletonizer (el esqueleto que se ve mientras cargan los datos) qué tema usar. Sin
          // esto usaría siempre el del móvil, aunque el usuario haya elegido otro en Perfil.
          // En "Sistema" se deja en null y entonces sí usa el del móvil
          builder: (_, child) => SkeletonizerConfig(
            data: SkeletonizerConfigData(
              brightness: switch (themeProvider.mode) {
                ThemeMode.light => Brightness.light,
                ThemeMode.dark => Brightness.dark,
                ThemeMode.system => null,
              },
            ),
            child: child!,
          ),
          // Pantalla de inicio: depende de si hay sesión o no
          home: const AuthGate(),
          getPages: [
            GetPage(name: '/register', page: () => const RegisterScreen()),
          ],
        ),
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
      // Mientras se lee la sesión guardada se ve la forma de la pantalla que va a venir, gris,
      // en vez de un círculo girando sobre el vacío. Skeletonizer es el mismo paquete que usan
      // las demás pantallas: pinta el contenido real como esqueleto.
      return const Scaffold(
        body: Skeletonizer(enabled: true, child: StartingSkeleton()),
      );
    }

    return auth.isLoggedIn ? const HomeScreen() : const LoginScreen();
  }
}

// Forma aproximada de la pantalla de inicio mientras se lee la sesión guardada: un título y unas
// tarjetas con el mismo aire que las listas de la app. El texto es de mentira, Skeletonizer lo tapa.
class StartingSkeleton extends StatelessWidget {
  const StartingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Cargando', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        for (var i = 0; i < 4; i++) ...[
          const Card(
            child: ListTile(
              title: Text('Entrenamiento'),
              subtitle: Text('Hace un rato'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
