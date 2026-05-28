// lib/presentation/screens/register_screen.dart
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
  final _telefonoCtrl = TextEditingController();
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
      setState(() => _error = 'Complete los campos obligatorios');
      return;
    }
    
    if (!email.contains('@')) {
      setState(() => _error = 'Correo no válido');
      return;
    }

    if (pass.length < 6) {
      setState(() => _error = 'Contraseña debe tener al menos 6 caracteres');
      return;
    }

    if (pass != confirm) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }

    if (_role == 'Paciente' && _supervisorEmailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Complete el correo del supervisor');
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
        peso: _role == 'Paciente' ? _peso.toDouble() : null,
        altura: _role == 'Paciente' ? _altura : null,
        sexo: _sexo,
        telefono: _role == 'Supervisor' ? _telefonoCtrl.text.trim() : null,
        role: _role,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta creada correctamente'), backgroundColor: Color(0xFF10B981)),
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
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Crear Cuenta',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            const Text(
              'Ingresa tus datos para comenzar el monitoreo de salud',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Base Form Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF131929),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  _textField(icon: Icons.person_outline, hint: 'Nombre completo', controller: _nameCtrl),
                  const SizedBox(height: 12),
                  _textField(icon: Icons.email_outlined, hint: 'Correo electrónico', controller: _emailCtrl),
                  const SizedBox(height: 12),
                  _textField(icon: Icons.lock_outline, hint: 'Contraseña', controller: _passCtrl, obscure: true),
                  const SizedBox(height: 12),
                  _textField(icon: Icons.lock_outline, hint: 'Confirmar contraseña', controller: _confirmCtrl, obscure: true),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Role Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF131929),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.badge_outlined, color: Colors.white54, size: 20),
                      const SizedBox(width: 12),
                      const Text('Tipo de Cuenta', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const Spacer(),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _role,
                          dropdownColor: const Color(0xFF131929),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          items: ['Paciente', 'Supervisor'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                          onChanged: (v) => setState(() => _role = v!),
                        ),
                      ),
                    ],
                  ),
                  if (_role == 'Paciente') ...[
                    const Divider(color: Colors.white12, height: 16),
                    _textField(icon: Icons.supervisor_account_outlined, hint: 'Correo de tu Supervisor', controller: _supervisorEmailCtrl),
                  ]
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Biometrics or Phone Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF131929),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  if (_role == 'Supervisor') ...[
                    _textField(icon: Icons.phone_android_outlined, hint: 'Número de Teléfono', controller: _telefonoCtrl, isNumber: true),
                    const SizedBox(height: 12),
                  ],
                  if (_role == 'Paciente') ...[
                    _stepperRow('Edad', '$_edad años', () => setState(() => _edad = (_edad - 1).clamp(10, 100)), () => setState(() => _edad = (_edad + 1).clamp(10, 100))),
                    const Divider(color: Colors.white12, height: 16),
                    _stepperRow('Peso', '${_peso} kg', () => setState(() => _peso = (_peso - 1).clamp(30, 200)), () => setState(() => _peso = (_peso + 1).clamp(30, 200))),
                    const Divider(color: Colors.white12, height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.height, color: Colors.white54, size: 20),
                          const SizedBox(width: 12),
                          const Text('Altura', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          const Spacer(),
                          IconButton(icon: const Icon(Icons.remove, color: Colors.white70, size: 18), onPressed: () => setState(() => _altura = (_altura - 0.01).clamp(1.0, 2.5))),
                          Text('${_altura.toStringAsFixed(2)} m', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          IconButton(icon: const Icon(Icons.add, color: Colors.white70, size: 18), onPressed: () => setState(() => _altura = (_altura + 0.01).clamp(1.0, 2.5))),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 16),
                  ],
                  Row(
                    children: [
                      const Icon(Icons.wc_outlined, color: Colors.white54, size: 20),
                      const SizedBox(width: 12),
                      const Text('Sexo', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const Spacer(),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sexo,
                          dropdownColor: const Color(0xFF131929),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          items: ['Masculino', 'Femenino', 'Otro'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                          onChanged: (v) => setState(() => _sexo = v!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
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

            const SizedBox(height: 28),
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
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Crear Cuenta', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('¿Ya tienes una cuenta?', style: TextStyle(color: Colors.white54, fontSize: 13)),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Iniciar sesión', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 13)),
                )
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _textField({required IconData icon, required String hint, required TextEditingController controller, bool obscure = false, bool isNumber = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.white54, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _stepperRow(String label, String value, VoidCallback dec, VoidCallback inc) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const Spacer(),
        _stepBtn(Icons.remove, dec),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        _stepBtn(Icons.add, inc),
      ],
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}
