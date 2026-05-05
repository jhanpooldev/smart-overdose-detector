// lib/presentation/screens/umbrales_screen.dart
// Pantalla de Umbrales — calcula automáticamente con fórmula de Tanaka
// Supervisor puede ver y ajustar valores del paciente seleccionado.
// Paciente solo ve sus propios umbrales (solo lectura).
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../infrastructure/auth/auth_service.dart';
import '../../domain/entities/user.dart';

class UmbralesScreen extends StatefulWidget {
  /// Si se proporciona [patientId], el supervisor ve los umbrales de ese paciente.
  final String? patientId;
  const UmbralesScreen({super.key, this.patientId});

  @override
  State<UmbralesScreen> createState() => _UmbralesScreenState();
}

class _UmbralesScreenState extends State<UmbralesScreen> {
  // Datos de la fórmula
  int _edad = 30;
  double _peso = 70.0;
  double _altura = 1.70;
  String _sexo = 'Masculino';

  // Umbrales calculados
  Map<String, dynamic>? _thresholds;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  bool get _isSupervisor => AuthService().currentUser?.role == Role.supervisor;

  @override
  void initState() {
    super.initState();
    _fetchThresholds();
  }

  /// Cálculo local de Tanaka (sin red) para actualización instantánea al mover sliders
  Map<String, dynamic> _tanaka({required int edad, required double peso, required double altura}) {
    final fcMax = 208 - (0.7 * edad);
    final imc = peso / (altura * altura);
    final ajuste = imc > 30 ? 5 : 0;
    return {
      'fc_max': fcMax.round(),
      'imc': double.parse(imc.toStringAsFixed(1)),
      'bpm': {
        'normal_min': 60,
        'normal_max': (0.75 * fcMax).round() - ajuste,
        'moderate_lo': (0.50 * fcMax).round(),
        'moderate_hi': (0.90 * fcMax).round() + ajuste,
        'critical_lo': 50,
        'critical_hi': fcMax.round() + ajuste,
      },
      'spo2': {
        'normal_min': 95.0,
        'moderate_min': 90.0,
        'critical_max': 82.0,
      },
    };
  }

  Future<void> _fetchThresholds() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final auth = AuthService();
      final pid = widget.patientId;
      final url = pid != null
          ? '${auth.baseUrl}/thresholds/$pid'
          : '${auth.baseUrl}/thresholds';
      final resp = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _thresholds = data;
          _isLoading = false;
        });
      } else {
        // Calcular localmente si el endpoint falla
        setState(() {
          _thresholds = _tanaka(edad: _edad, peso: _peso, altura: _altura);
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _thresholds = _tanaka(edad: _edad, peso: _peso, altura: _altura);
        _isLoading = false;
      });
    }
  }

  void _recalculate() {
    setState(() { _thresholds = _tanaka(edad: _edad, peso: _peso, altura: _altura); });
  }

  Future<void> _saveThresholds() async {
    if (widget.patientId == null) return;
    setState(() => _isSaving = true);
    try {
      final auth = AuthService();
      final url = '${auth.baseUrl.replaceAll('/auth', '')}/auth/thresholds/${widget.patientId}';
      final resp = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'edad': _edad,
          'peso': _peso,
          'altura': _altura,
        }),
      );

      if (resp.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Umbrales guardados correctamente'), backgroundColor: Color(0xFF10B981)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Error al guardar umbrales'), backgroundColor: Color(0xFFDC2626)),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Error de conexión'), backgroundColor: Color(0xFFDC2626)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))));

    final bpm = _thresholds!['bpm'] as Map<String, dynamic>;
    final spo2 = _thresholds!['spo2'] as Map<String, dynamic>;
    final imc = (_thresholds!['imc'] as num).toDouble();
    final fcMax = _thresholds!['fc_max'] as int;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D4ED8),
        title: const Row(
          children: [
            Icon(Icons.tune_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Umbrales Clínicos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner informativo para paciente
          if (!_isSupervisor)
            _infoCard('Solo tu Supervisor puede ajustar estos parámetros. Son calculados a partir de tus datos biométricos.'),

          // === Parámetros biométricos (solo editable por supervisor) ===
          _sectionTitle('Parámetros del Paciente'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _sliderRow('Edad', '$_edad años', _edad.toDouble(), 10, 100, _isSupervisor,
                    (v) { _edad = v.round(); _recalculate(); }),
                  const Divider(height: 1),
                  _sliderRow('Peso', '${_peso.toStringAsFixed(1)} kg', _peso, 30, 200, _isSupervisor,
                    (v) { _peso = v; _recalculate(); }),
                  const Divider(height: 1),
                  _sliderRow('Altura', '${_altura.toStringAsFixed(2)} m', _altura, 1.0, 2.5, _isSupervisor,
                    (v) { _altura = v; _recalculate(); }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          // IMC calculado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: imc > 30 ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(imc > 30 ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                    color: imc > 30 ? const Color(0xFFF59E0B) : const Color(0xFF10B981), size: 18),
                const SizedBox(width: 8),
                Text('IMC: $imc  |  FC Máx: $fcMax BPM  |  ${imc > 30 ? "Ajuste por obesidad aplicado (+5 BPM)" : "Peso normal"}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
              ],
            ),
          ),

          const SizedBox(height: 16),
          // === Umbrales calculados ===
          _sectionTitle('Umbrales Calculados Automáticamente'),
          _thresholdCard(
            color: const Color(0xFF10B981),
            icon: Icons.check_circle_rounded,
            label: 'Normal',
            lines: ['BPM: ${bpm['normal_min']} – ${bpm['normal_max']}', 'SpO₂: ≥ ${spo2['normal_min']}%'],
          ),
          const SizedBox(height: 8),
          _thresholdCard(
            color: const Color(0xFFF59E0B),
            icon: Icons.warning_rounded,
            label: 'Moderado',
            lines: ['BPM: ${bpm['moderate_lo']} – ${bpm['moderate_hi']}', 'SpO₂: ${spo2['moderate_min']}% – ${spo2['normal_min']}%'],
          ),
          const SizedBox(height: 8),
          _thresholdCard(
            color: const Color(0xFFDC2626),
            icon: Icons.dangerous_rounded,
            label: 'Crítico',
            lines: ['BPM: < ${bpm['critical_lo']} o > ${bpm['critical_hi']}', 'SpO₂: < ${spo2['critical_max']}%'],
          ),

          const SizedBox(height: 24),
          if (_isSupervisor)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveThresholds,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, color: Colors.white),
                label: Text(_isSaving ? 'Guardando...' : 'Guardar Umbrales',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
  );

  Widget _infoCard(String msg) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF3C7),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(color: Color(0xFF92400E), fontSize: 12))),
      ],
    ),
  );

  Widget _thresholdCard({required Color color, required IconData icon, required String label, required List<String> lines}) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines.map((l) => Text(l, style: const TextStyle(fontSize: 12, color: Color(0xFF374151)))).toList(),
        ),
      ),
    );
  }

  Widget _sliderRow(String label, String valueStr, double value, double min, double max, bool enabled, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFF2563EB).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(valueStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB))),
              ),
              if (!enabled) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.lock_outline, size: 14, color: Color(0xFFD1D5DB))),
            ],
          ),
          if (enabled)
            Slider(
              value: value,
              min: min,
              max: max,
              activeColor: const Color(0xFF2563EB),
              inactiveColor: const Color(0xFFE5E7EB),
              onChanged: enabled ? (v) => setState(() => onChanged(v)) : null,
            ),
        ],
      ),
    );
  }
}
