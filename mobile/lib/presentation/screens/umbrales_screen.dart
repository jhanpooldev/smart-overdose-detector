// lib/presentation/screens/umbrales_screen.dart
// Pantalla 3 (⚙️) — Configurar Umbrales (Doctor puede editar, otros solo ven)
import 'package:flutter/material.dart';
import '../../infrastructure/auth/auth_service.dart';
import '../../domain/entities/user.dart';

class UmbralesScreen extends StatefulWidget {
  const UmbralesScreen({super.key});

  @override
  State<UmbralesScreen> createState() => _UmbralesScreenState();
}

class _UmbralesScreenState extends State<UmbralesScreen> {
  // Valores actuales
  String _bpmNormal = '60 – 100 BPM';
  String _bpmModerado = '101 – 130 BPM';
  String _bpmCritico = '< 50 BPM o > 130 BPM';
  int _peso = 75;
  double _altura = 1.75;
  String _historialRiesgo = 'Riesgo Alto';

  // Opciones de los dropdowns
  final List<String> _bpmNormalOptions = ['50 – 90 BPM', '60 – 100 BPM', '60 – 110 BPM'];
  final List<String> _bpmModeradoOptions = ['91 – 120 BPM', '101 – 130 BPM', '111 – 140 BPM'];
  final List<String> _bpmCriticoOptions = ['< 45 BPM o > 120 BPM', '< 50 BPM o > 130 BPM', '< 55 BPM o > 140 BPM'];
  final List<String> _riesgoOptions = ['Riesgo Bajo', 'Riesgo Moderado', 'Riesgo Alto', 'Riesgo Crítico'];

  @override
  Widget build(BuildContext context) {
    final isSupervisor = AuthService().currentUser?.role == Role.supervisor;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D4ED8),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.settings_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Configurar Umbrales', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!isSupervisor)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text('Solo el Supervisor puede modificar estos parámetros.', style: TextStyle(color: Color(0xFF92400E), fontSize: 12))),
                ],
              ),
            ),

          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _dropdownRow('< ${_bpmNormal}', _bpmNormalOptions, _bpmNormal, isSupervisor, (v) => setState(() => _bpmNormal = v!)),
                  const Divider(height: 1),
                  _dropdownRow('${_bpmModerado}', _bpmModeradoOptions, _bpmModerado, isSupervisor, (v) => setState(() => _bpmModerado = v!)),
                  const Divider(height: 1),
                  _dropdownRow('${_bpmCritico}', _bpmCriticoOptions, _bpmCritico, isSupervisor, (v) => setState(() => _bpmCritico = v!)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Peso y Altura
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _stepperRow('Peso', '${_peso} kg', isSupervisor,
                    () => setState(() => _peso = (_peso - 1).clamp(30, 200)),
                    () => setState(() => _peso = (_peso + 1).clamp(30, 200)),
                  ),
                  const Divider(height: 1),
                  _stepperRow('Altura', '${_altura.toStringAsFixed(2)} m', isSupervisor,
                    () => setState(() => _altura = (_altura - 0.01).clamp(1.0, 2.5)),
                    () => setState(() => _altura = (_altura + 0.01).clamp(1.0, 2.5)),
                  ),
                  const Divider(height: 1),
                  _dropdownRow('Historial:', _riesgoOptions, _historialRiesgo, isSupervisor, (v) => setState(() => _historialRiesgo = v!)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          if (isSupervisor)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Parámetros guardados correctamente'), backgroundColor: Color(0xFF10B981)),
                  );
                },
                child: const Text('Guardar Cambios', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dropdownRow(String display, List<String> options, String current, bool enabled, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text('< $current', style: const TextStyle(color: Color(0xFF374151), fontSize: 13))),
          if (enabled)
            DropdownButton<String>(
              value: current,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2563EB)),
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: onChanged,
            )
          else
            const Icon(Icons.lock_outline, color: Color(0xFFD1D5DB), size: 16),
        ],
      ),
    );
  }

  Widget _stepperRow(String label, String value, bool enabled, VoidCallback dec, VoidCallback inc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF374151), fontSize: 14)),
          const Spacer(),
          if (enabled) ...[
            _stepBtn(Icons.remove, dec),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            _stepBtn(Icons.add, inc),
          ] else
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}
