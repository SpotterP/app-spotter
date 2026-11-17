import 'package:flutter/material.dart';

import 'profile_screen.dart';

// Pantalla principal cuando hay sesión. Tiene una barra de abajo para cambiar entre pestañas.
// Ahora solo hay Inicio (vacía) y Perfil; las siguientes pantallas (rutinas, entrenamientos) irán aquí.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Pestaña que se está viendo (0 = Inicio, 1 = Perfil)
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack mantiene las pestañas vivas y solo enseña la elegida
      body: IndexedStack(
        index: _index,
        children: const [
          Center(child: Text('Aquí irán tus rutinas')),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
