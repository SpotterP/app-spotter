import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';

// Pantalla de perfil: enseña el nombre y el email del usuario y permite cerrar la sesión.
// Al abrirla pide los datos a la API (GET /users/me).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    // Esperamos a que termine de construirse la pantalla antes de llamar a la API
    Future.microtask(() => auth.loadProfile());
  }

  // Iniciales del nombre para el círculo del avatar ("Ana Pérez" -> "AP")
  String _initials(String name) {
    final words = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    // Si no hay usuario (por ejemplo justo al cerrar sesión) no pintamos nada
    if (user == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Barra de carga mientras se piden los datos a la API
          if (auth.profileLoading) const LinearProgressIndicator(),
          // Si la API falla seguimos enseñando los datos que teníamos y avisamos del error
          if (auth.profileError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(auth.profileError!, style: const TextStyle(color: AppColors.danger), textAlign: TextAlign.center),
            ),
          Center(
            child: CircleAvatar(
              radius: 44,
              // Estos colores salen del tema, así se ven bien tanto en claro como en oscuro
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                _initials(user.name),
                style: TextStyle(fontSize: 28, color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Sin color propio: el texto toma el color del tema (oscuro en claro y claro en oscuro)
          Center(child: Text(user.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(leading: const Icon(Icons.person_outline), title: const Text('Nombre'), subtitle: Text(user.name)),
                const Divider(height: 1),
                ListTile(leading: const Icon(Icons.email_outlined), title: const Text('Email'), subtitle: Text(user.email)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Elegir el tema de la app: claro, oscuro o el mismo que tenga el móvil
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tema', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro')),
                      ButtonSegment(value: ThemeMode.system, label: Text('Sistema')),
                    ],
                    selected: {context.watch<ThemeProvider>().mode},
                    onSelectionChanged: (selection) => context.read<ThemeProvider>().setMode(selection.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout, color: AppColors.danger),
            label: const Text('Cerrar sesión', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}
