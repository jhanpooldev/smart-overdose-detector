// lib/presentation/screens/register_screen.dart
// Pantalla "Crear Cuenta" basada en el mockup del usuario
import 'package:flutter/material.dart';
import '../../infrastructure/auth/auth_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _supervisorEmailCtrl = TextEditingController();
  int _edad = 30;
  int _peso = 75;
  double _altura = 1.70;
  String _sexo = 'Masculino';
  String _role = 'Paciente';
  bool _isLoading = false;
  String? _error;

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'complete los campos obligatorios');
      return;
    }
    
    if (!email.contains('@')) {
      setState(() => _error = 'correo no válido');
      return;
    }

    if (pass.length < 6) {
      setState(() => _error = 'contraseña inválida');
      return;
    }

    if (pass != confirm) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }

    if (_role == 'Paciente' && _supervisorEmailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'complete los campos obligatorios');
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    try {
      await AuthService().register(
        email, 
        pass, 
        name, 
        supervisorEmail: _role == 'Paciente' ? _supervisorEmailCtrl.text.trim() : null,
        edad: _edad,
        peso: _peso.toDouble(),
        altura: _altura,
        sexo: _sexo,
        role: _role,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta creada correctamente'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
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
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF2563EB)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Crear Cuenta',
            style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        child: Column(
          children: [
            const Text(
              'Ingresa tus datos para comenzar\nel monitoreo de salud',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF4B5563), fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Form card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(
                children: [
                  _textField(icon: Icons.person_outline, hint: 'Nombre completo', controller: _nameCtrl),
                  const Divider(height: 1),
                  _textField(icon: Icons.email_outlined, hint: 'Correo electrónico', controller: _emailCtrl),
                  const Divider(height: 1),
                  _textField(icon: Icons.lock_outline, hint: 'Contraseña', controller: _passCtrl, obscure: true),
                  const Divider(height: 1),
                  _textField(icon: Icons.lock_outline, hint: 'Confirmar contraseña', controller: _confirmCtrl, obscure: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.badge_outlined, color: Color(0xFF9CA3AF), size: 20),
                        const SizedBox(width: 12),
                        const Text('Rol', style: TextStyle(color: Color(0xFF4B5563))),
                        const Spacer(),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _role,
                            items: ['Paciente', 'Supervisor'].map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 14)))).toList(),
                            onChanged: (v) => setState(() => _role = v!),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_role == 'Paciente') ...[
                    const Divider(height: 1),
                    _textField(icon: Icons.supervisor_account_outlined, hint: 'Correo de tu Supervisor', controller: _supervisorEmailCtrl),
                  ]
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Edad, peso, sexo
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(
                children: [
                  _stepperRow('Edad', '$_edad años', () => setState(() => _edad = (_edad - 1).clamp(10, 100)), () => setState(() => _edad = (_edad + 1).clamp(10, 100))),
                  const Divider(height: 1),
                  _stepperRow('Peso', '${_peso} kg', () => setState(() => _peso = (_peso - 1).clamp(30, 200)), () => setState(() => _peso = (_peso + 1).clamp(30, 200))),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.height, color: Color(0xFF9CA3AF), size: 20),
                        const SizedBox(width: 12),
                        const Text('Altura', style: TextStyle(color: Color(0xFF4B5563))),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.remove, size: 18), onPressed: () => setState(() => _altura = (_altura - 0.01).clamp(1.0, 2.5))),
                        Text('${_altura.toStringAsFixed(2)} m', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        IconButton(icon: const Icon(Icons.add, size: 18), onPressed: () => setState(() => _altura = (_altura + 0.01).clamp(1.0, 2.5))),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.wc_outlined, color: Color(0xFF9CA3AF), size: 20),
                        const SizedBox(width: 12),
                        const Text('Sexo', style: TextStyle(color: Color(0xFF4B5563))),
                        const Spacer(),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sexo,
                            items: ['Masculino', 'Femenino', 'Otro'].map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 14)))).toList(),
                            onChanged: (v) => setState(() => _sexo = v!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Crear Cuenta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('¿Ya tienes una cuenta?', style: TextStyle(color: Color(0xFF4B5563), fontSize: 13)),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Iniciar sesión', style: TextStyle(color: Color(0xFF2563EB), fontSize: 13)),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _textField({required IconData icon, required String hint, required TextEditingController controller, bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Color(0xFF111827), fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _stepperRow(String label, String value, VoidCallback dec, VoidCallback inc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 14)),
          const Spacer(),
          _stepBtn(Icons.remove, dec),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          _stepBtn(Icons.add, inc),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}
