import 'package:flutter/material.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';

// Pantalla para iniciar sesión. Si el login va bien, el AuthProvider cambia
// y main.dart enseña la pantalla principal solo (no hace falta navegar a mano).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Si algún campo no es válido, no llamamos a la API
    if (!_formKey.currentState!.validate()) return;

    await context.read<AuthProvider>().login(_emailController.text.trim(), _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(Icons.fitness_center, size: 64, color: AppColors.primary),
                  const SizedBox(height: 8),
                  const Text('Spotter', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    // Regla ya hecha de email: un email como "a@b" no vale. Antes de mirarlo se quitan los espacios
                    // de los lados, porque el teclado del móvil los suele añadir al autocompletar
                    validator: FormBuilderValidators.transform(
                      (value) => (value ?? '').trim(),
                      FormBuilderValidators.email(errorText: 'Escribe un email válido'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                    // Al entrar solo se pide que no esté vacía: la longitud ya se comprobó al registrarse
                    validator: FormBuilderValidators.required(errorText: 'Escribe la contraseña'),
                  ),
                  // Error de la API (por ejemplo "Email o contraseña incorrectos")
                  if (auth.error != null) ...[
                    const SizedBox(height: 16),
                    Text(auth.error!, style: const TextStyle(color: AppColors.danger), textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      // Con loading a true el botón se desactiva
                      onPressed: auth.loading ? null : _submit,
                      child: auth.loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Iniciar sesión'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      auth.clearError();
                      Get.toNamed('/register');
                    },
                    child: const Text('¿No tienes cuenta? Regístrate'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
