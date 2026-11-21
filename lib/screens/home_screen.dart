import 'package:flutter/material.dart';

import 'profile_screen.dart';
import 'routines_screen.dart';

// Pantalla principal cuando hay sesión. Tiene una barra de abajo con las 5 secciones de la app.
// Rutinas y Perfil están hechas; las otras tres enseñan un texto hasta que se hagan sus pantallas.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Pestaña que se está viendo (0 = Entrenar, 1 = Mis rutinas, 2 = Calendario, 3 = Progreso, 4 = Perfil)
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack mantiene las pestañas vivas y solo enseña la elegida
      body: IndexedStack(
        index: _index,
        children: const [
          Center(child: Text('Aquí podrás entrenar')),
          RoutinesScreen(),
          Center(child: Text('Aquí irá el calendario')),
          Center(child: Text('Aquí irá tu progreso')),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.play_circle_outline), selectedIcon: Icon(Icons.play_circle), label: 'Entrenar'),
          NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'Rutinas'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendario'),
          NavigationDestination(icon: Icon(Icons.show_chart), selectedIcon: Icon(Icons.show_chart), label: 'Progreso'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
