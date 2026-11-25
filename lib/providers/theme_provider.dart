import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Guarda el tema que ha elegido el usuario (claro, oscuro o el del móvil) y avisa a la app cuando cambia.
// La elección se guarda en el móvil (SharedPreferences) para que siga al cerrar la app.
class ThemeProvider extends ChangeNotifier {
  // Por defecto la app sigue el tema del móvil
  ThemeMode mode = ThemeMode.system;

  // Lee el tema guardado. Se llama una vez al crear el provider
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('themeMode');

    // Si hay un tema guardado lo usamos; si no, nos quedamos con el del móvil
    mode = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
    notifyListeners();
  }

  // Cambia el tema, avisa a la app para que se repinte y lo guarda
  Future<void> setMode(ThemeMode newMode) async {
    mode = newMode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', newMode.name);
  }
}
