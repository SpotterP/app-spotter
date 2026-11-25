import 'package:flutter/material.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:regex_ui/regex_ui.dart';

import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';

// Pantalla para crear una cuenta nueva. La API no devuelve token al registrar,
// así que después volvemos al login para que el usuario inicie sesión.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await context.read<AuthProvider>().register(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
        );

    // Si se ha creado la cuenta, volvemos al login y avisamos
    if (ok) {
      Get.back();
      Get.snackbar('Cuenta creada', 'Ya puedes iniciar sesión');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                    validator: FormBuilderValidators.required(errorText: 'Escribe tu nombre'),
                  ),
                  const SizedBox(height: 16),
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
                    // errorText enseña el motivo si la API rechaza la contraseña, junto a su campo
                    decoration: InputDecoration(labelText: 'Contraseña', border: const OutlineInputBorder(), errorText: auth.passwordError),
                    // Al escribir de nuevo, el motivo del rechazo anterior ya no vale
                    onChanged: (_) {
                      if (auth.passwordError != null) auth.clearError();
                    },
                    // La API pide mínimo 8 caracteres: es lo único que impide enviar el formulario
                    validator: FormBuilderValidators.minLength(8, errorText: 'Mínimo 8 caracteres'),
                  ),
                  // Indicador de fortaleza (débil, media o fuerte) y lista de lo que le falta a la contraseña.
                  // Se actualiza con cada carácter. Solo ayuda: no bloquea nada, la API solo exige 8 caracteres
                  RegexUI(
                    controller: _passwordController,
                    regexList: RegexModel.passwordRules(),
                    showStrength: true,
                    strengthMode: RegexUIStrength.password,
                    // El paquete usa 5 niveles y aquí se enseñan 3
                    strengthLabels: const ['Débil', 'Débil', 'Media', 'Media', 'Fuerte'],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Repite la contraseña', border: OutlineInputBorder()),
                    // Solo se comprueba aquí: a la API le llega una sola contraseña
                    validator: RegexModel.validator([RegexModel.sameAs(_passwordController, title: 'Las contraseñas no coinciden')]),
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: 16),
                    Text(auth.error!, style: const TextStyle(color: AppColors.danger), textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: auth.loading ? null : _submit,
                      child: auth.loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Crear cuenta'),
                    ),
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
