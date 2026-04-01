import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final hogarController = TextEditingController();
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool isLoading = false;

  Future<void> register() async {
    if (isLoading) return; 
    if (emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      _showError('Por favor completa todos los campos');
      return;
    }
    
    if (passwordController.text != confirmPasswordController.text) {
      _showError('Las contraseñas no coinciden');
      return;
    }

    if (passwordController.text.length < 6) {
      _showError('La contraseña debe tener al menos 6 caracteres');
      return;
    }
    if (hogarController.text.isEmpty) {
     _showError('Ingresa el hogar comunitario');
    return;
    }
     if (usernameController.text.isEmpty) {
      _showError('Ingresa un nombre de usuario');
      return;
   }

    setState(() => isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // Registrar usuario en Auth
      final response = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (response.user != null) {
        // Insertar datos en tabla usuarios con columnas correctas
        await supabase.from('usuarios').insert({
          'id': response.user!.id,
          'nombre': usernameController.text.trim(),
          'correo': emailController.text.trim(),
          'nombre_hogar': hogarController.text.trim(),
          'created_at': DateTime.now().toIso8601String(),
        });

        _showSuccess('Registro exitoso. Inicia sesión');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          }
        });
      }
    } on AuthException catch (e) {
      if (e.message.contains('over_email_send_rate_limit')) {
        _showError('Espera unos minutos antes de intentar de nuevo');
      } else if (e.message.contains('anonymous_provider_disabled')) {
        _showError('Configuración de autenticación incorrecta');
      } else {
        _showError('Error: ${e.message}');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF8F88D9)),
      filled: true,
      fillColor: const Color(0xFFF8F5FF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE5DDFB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFB39DDB), width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF1F2), Color(0xFFEAF7FF), Color(0xFFF4EEFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.7)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F8C93B5),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFF8C8DC), Color(0xFFA7D8FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(
                            Icons.person_add_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Crear cuenta',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4E4A67),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Regístrate para acceder a la plataforma',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: Color(0xFF7A7890),
                        ),
                      ),
                      const SizedBox(height: 16),

TextField(
  controller: hogarController,
  enabled: !isLoading,
  decoration: _inputDecoration(
    label: 'Hogar comunitario',
    icon: Icons.home_rounded,
  ),
),
const SizedBox(height: 16),

TextField(
  controller: usernameController,
  enabled: !isLoading,
  decoration: _inputDecoration(
    label: 'Nombre de usuario',
    icon: Icons.person_outline_rounded,
  ),
),
                      const SizedBox(height: 24),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !isLoading,
                        decoration: _inputDecoration(
                          label: 'Correo electrónico',
                          icon: Icons.mail_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        enabled: !isLoading,
                        decoration: _inputDecoration(
                          label: 'Contraseña',
                          icon: Icons.lock_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: true,
                        enabled: !isLoading,
                        decoration: _inputDecoration(
                          label: 'Confirmar contraseña',
                          icon: Icons.lock_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFB39DDB), Color(0xFF81D4D4)],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x3381D4D4),
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Registrarse',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton(
                          onPressed: isLoading
                              ? null
                              : () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LoginPage(),
                                    ),
                                  );
                                },
                          child: const Text(
                            '¿Ya tienes cuenta? Inicia sesión',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFFB39DDB),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    hogarController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}