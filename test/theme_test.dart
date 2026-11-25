import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_spotter/providers/theme_provider.dart';

// Tests sencillos del tema: por defecto sigue al móvil y lo que se elige se guarda
void main() {
  test('por defecto la app sigue el tema del móvil', () async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeProvider();

    await theme.loadTheme();

    expect(theme.mode, ThemeMode.system);
  });

  test('el tema elegido se guarda y se recupera al volver a abrir la app', () async {
    SharedPreferences.setMockInitialValues({});
    await ThemeProvider().setMode(ThemeMode.dark);

    // Un provider nuevo, como al abrir la app otra vez, lee lo guardado
    final reopened = ThemeProvider();
    await reopened.loadTheme();

    expect(reopened.mode, ThemeMode.dark);
  });
}
