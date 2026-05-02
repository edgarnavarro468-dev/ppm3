import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../app/app.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  late final TextEditingController _baseUrlController;
  bool _isLogin = true;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(text: PpmApiClient.defaultBaseUrl);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _baseUrlController.text = AppScope.of(context).baseUrl;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                Text(
                  'PPM Mobile',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Agregar un gasto y entender saldos debe sentirse inmediato.',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Cliente movil Flutter enfocado en el flujo real: entrar, ver quien debe, registrar gasto y seguir.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment<bool>(value: true, label: Text('Entrar')),
                            ButtonSegment<bool>(value: false, label: Text('Crear cuenta')),
                          ],
                          selected: {_isLogin},
                          onSelectionChanged: (values) {
                            setState(() => _isLogin = values.first);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _baseUrlController,
                          decoration: const InputDecoration(
                            labelText: 'URL base de la API',
                            helperText: 'Android emulator: http://10.0.2.2:8000',
                          ),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 12),
                        if (!_isLogin) ...[
                          TextField(
                            controller: _usernameController,
                            decoration: const InputDecoration(labelText: 'Usuario'),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _firstNameController,
                                  decoration: const InputDecoration(labelText: 'Nombre'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _lastNameController,
                                  decoration: const InputDecoration(labelText: 'Apellido'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: 'Correo'),
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: _isLogin ? 'Contrasena' : 'Contrasena (minimo 8 caracteres)',
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: state.isBusy ? null : () => _submit(context),
                          child: Text(_isLogin ? 'Entrar y cargar grupos' : 'Crear cuenta y abrir app'),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tip de prueba: si usas un telefono fisico, cambia la URL a la IP local de tu computadora.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.isBusy) ...[
                  const SizedBox(height: 18),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final state = AppScope.of(context);
    state.updateBaseUrl(_baseUrlController.text);

    try {
      if (_isLogin) {
        await state.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await state.register(
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
        );
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ocurrio un error inesperado al autenticar.')),
      );
    }
  }
}
