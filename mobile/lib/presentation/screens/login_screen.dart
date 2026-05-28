// lib/presentation/screens/login_screen.dart
import 'package:flutter/material.dart';
import '../../infrastructure/auth/auth_service.dart';
import 'home_shell.dart';
import 'register_screen.dart';
import 'package:local_auth/local_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  String? _error;

  final _localAuth = LocalAuthentication();
  bool _hasBiometrics = false;
  bool _hasCredentials = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      final creds = await AuthService().getSavedCredentials();
      if (mounted) {
        setState(() {
          _hasBiometrics = canCheck;
          _hasCredentials = creds != null;
        });
      }
    } catch (e) {
      debugPrint('Biometrics check error: $e');
    }
  }

  Future<void> _biometricLogin() async {
    if (!_hasCredentials) {
      setState(() => _error = 'No hay credenciales guardadas. Inicie sesión manualmente primero.');
      return;
    }
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Autentíquese para ingresar a Smart Overdose Detector',
      );
      if (authenticated) {
        final creds = await AuthService().getSavedCredentials();
        if (creds != null) {
          _emailCtrl.text = creds['email']!;
          _passCtrl.text = creds['password']!;
          await _login();
        }
      }
    } catch (e) {
      setState(() => _error = 'Error de autenticación biométrica');
    }
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Complete los campos obligatorios');
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    try {
      await AuthService().login(email, password);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeShell()),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString().replaceAll("Exception: ", "");
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Beautiful animated heart logo
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.25), width: 1),
                ),
                child: const Icon(Icons.monitor_heart_rounded, size: 58, color: Color(0xFF2563EB)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Smart Overdose Detector',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              const Text(
                'Detección Temprana & Monitoreo en Tiempo Real',
                style: TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              // Inputs Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF131929),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    _input(
                      controller: _emailCtrl,
                      icon: Icons.email_outlined,
                      hint: 'Correo electrónico',
                    ),
                    const SizedBox(height: 12),
                    _input(
                      controller: _passCtrl,
                      icon: Icons.lock_outline,
                      hint: 'Contraseña',
                      obscure: _obscure,
                      suffix: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white54, size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7F1D1D).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12))),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(color: Color(0xFF2563EB), fontSize: 12)),
                ),
              ),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Iniciar Sesión', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),

              if (_hasBiometrics && _hasCredentials) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: const Color(0xFF2563EB).withOpacity(0.5)),
                      foregroundColor: const Color(0xFF60A5FA),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.fingerprint_rounded, size: 22),
                    label: const Text('Ingresar con Biometría', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    onPressed: _isLoading ? null : _biometricLogin,
                  ),
                ),
              ],

              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('¿Aún no tienes cuenta?', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: const Text('Crear cuenta', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input({required TextEditingController controller, required IconData icon, required String hint, bool obscure = false, Widget? suffix}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.white54, size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
