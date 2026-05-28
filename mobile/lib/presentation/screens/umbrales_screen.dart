// lib/presentation/screens/umbrales_screen.dart
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
  // Controllers para Biometría
  final _edadCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  final _alturaCtrl = TextEditingController();

  // Controllers para Umbrales Manuales
  final _bpmMinNormalCtrl = TextEditingController();
  final _bpmMaxNormalCtrl = TextEditingController();
  final _bpmMinModerateCtrl = TextEditingController();
  final _bpmMaxModerateCtrl = TextEditingController();
  final _spo2MinNormalCtrl = TextEditingController();
  final _spo2MinModerateCtrl = TextEditingController();
  final _spo2MinCriticalCtrl = TextEditingController();

  bool _isManual = false;
  Map<String, dynamic>? _thresholds;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchThresholds();
    
    // Add listeners to auto-calculate Tanaka if user edits biometrics
    _edadCtrl.addListener(_onBiometricsChanged);
    _pesoCtrl.addListener(_onBiometricsChanged);
    _alturaCtrl.addListener(_onBiometricsChanged);
  }

  @override
  void dispose() {
    _edadCtrl.dispose();
    _pesoCtrl.dispose();
    _alturaCtrl.dispose();
    _bpmMinNormalCtrl.dispose();
    _bpmMaxNormalCtrl.dispose();
    _bpmMinModerateCtrl.dispose();
    _bpmMaxModerateCtrl.dispose();
    _spo2MinNormalCtrl.dispose();
    _spo2MinModerateCtrl.dispose();
    _spo2MinCriticalCtrl.dispose();
    super.dispose();
  }

  /// Cálculo local de Tanaka
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
      'is_manual': false,
    };
  }

  Future<void> _fetchThresholds() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final auth = AuthService();
      final pid = widget.patientId ?? auth.currentUser?.id;
      final url = '${auth.baseUrl}/thresholds/$pid';
      
      final resp = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _thresholds = data;
          _isManual = data['is_manual'] ?? false;
          _isLoading = false;
        });

        // Set biometric fields
        final u = auth.currentUser;
        _edadCtrl.text = (u?.edad ?? 30).toString();
        _pesoCtrl.text = (u?.peso ?? 70.0).toString();
        _alturaCtrl.text = (u?.altura ?? 1.70).toString();

        _syncControllers(data);
      } else {
        _loadDefaults();
      }
    } catch (_) {
      _loadDefaults();
    }
  }

  void _loadDefaults() {
    final auth = AuthService();
    final u = auth.currentUser;
    final edad = u?.edad ?? 30;
    final peso = u?.peso ?? 70.0;
    final altura = u?.altura ?? 1.70;

    _edadCtrl.text = edad.toString();
    _pesoCtrl.text = peso.toString();
    _alturaCtrl.text = altura.toString();

    final data = _tanaka(edad: edad, peso: peso, altura: altura);
    setState(() {
      _thresholds = data;
      _isManual = false;
      _isLoading = false;
    });
    _syncControllers(data);
  }

  void _syncControllers(Map<String, dynamic> data) {
    final bpm = data['bpm'] as Map<String, dynamic>;
    final spo2 = data['spo2'] as Map<String, dynamic>;

    _bpmMinNormalCtrl.text = (bpm['normal_min'] ?? 60).toString();
    _bpmMaxNormalCtrl.text = (bpm['normal_max'] ?? 100).toString();
    _bpmMinModerateCtrl.text = (bpm['moderate_lo'] ?? 50).toString();
    _bpmMaxModerateCtrl.text = (bpm['moderate_hi'] ?? 130).toString();

    _spo2MinNormalCtrl.text = (spo2['normal_min'] ?? 95.0).toString();
    _spo2MinModerateCtrl.text = (spo2['moderate_min'] ?? 90.0).toString();
    _spo2MinCriticalCtrl.text = (spo2['critical_max'] ?? 82.0).toString();
  }

  void _onBiometricsChanged() {
    if (_isManual) return;
    final edad = int.tryParse(_edadCtrl.text) ?? 30;
    final peso = double.tryParse(_pesoCtrl.text) ?? 70.0;
    final altura = double.tryParse(_alturaCtrl.text) ?? 1.70;

    final tanakaData = _tanaka(edad: edad, peso: peso, altura: altura);
    setState(() {
      _thresholds = tanakaData;
    });
    _syncControllers(tanakaData);
  }

  Future<void> _saveThresholds() async {
    setState(() => _isSaving = true);
    try {
      final auth = AuthService();
      final pid = widget.patientId ?? auth.currentUser?.id;
      final url = '${auth.baseUrl}/thresholds/$pid';

      final body = <String, dynamic>{
        'edad': int.tryParse(_edadCtrl.text) ?? 30,
        'peso': double.tryParse(_pesoCtrl.text) ?? 70.0,
        'altura': double.tryParse(_alturaCtrl.text) ?? 1.70,
        'is_manual': _isManual,
      };

      if (_isManual) {
        body['bpm_min_normal'] = int.tryParse(_bpmMinNormalCtrl.text) ?? 60;
        body['bpm_max_normal'] = int.tryParse(_bpmMaxNormalCtrl.text) ?? 100;
        body['bpm_min_moderate'] = int.tryParse(_bpmMinModerateCtrl.text) ?? 50;
        body['bpm_max_moderate'] = int.tryParse(_bpmMaxModerateCtrl.text) ?? 130;
        body['spo2_min_normal'] = double.tryParse(_spo2MinNormalCtrl.text) ?? 95.0;
        body['spo2_min_moderate'] = double.tryParse(_spo2MinModerateCtrl.text) ?? 90.0;
        body['spo2_min_critical'] = double.tryParse(_spo2MinCriticalCtrl.text) ?? 82.0;
      }

      final resp = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Cambios guardados correctamente'), backgroundColor: Color(0xFF10B981)),
          );
        }
        _fetchThresholds();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Error al guardar en el servidor'), backgroundColor: Color(0xFFDC2626)),
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
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E1A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
      );
    }

    final imc = (_thresholds!['imc'] as num).toDouble();
    final fcMax = _thresholds!['fc_max'] as int;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.tune_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text('Umbrales Clínicos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Banner Informativo
          _infoCard('Personalice la biometría y active el modo manual si requiere configurar límites fijos.'),

          _sectionTitle('Perfil Biométrico'),
          _buildCard(
            child: Column(
              children: [
                _buildInputField('Edad', _edadCtrl, 'Años', Icons.cake),
                const SizedBox(height: 12),
                _buildInputField('Peso', _pesoCtrl, 'kg', Icons.monitor_weight),
                const SizedBox(height: 12),
                _buildInputField('Altura', _alturaCtrl, 'm', Icons.height),
              ],
            ),
          ),

          const SizedBox(height: 12),
          // IMC / FC Max Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: imc > 30 ? const Color(0xFF7F1D1D).withOpacity(0.3) : const Color(0xFF064E3B).withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: imc > 30 ? const Color(0xFFEF4444).withOpacity(0.4) : const Color(0xFF10B981).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Icon(imc > 30 ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                    color: imc > 30 ? const Color(0xFFF59E0B) : const Color(0xFF10B981), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'IMC: $imc  |  FC Máx: $fcMax BPM\n${imc > 30 ? "Ajuste por obesidad aplicado (+5 BPM)" : "Biometría normal"}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          // Modo Manual Toggle Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Modo Manual de Umbrales', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Switch(
                value: _isManual,
                activeColor: const Color(0xFF2563EB),
                onChanged: (val) {
                  setState(() {
                    _isManual = val;
                  });
                  _onBiometricsChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_isManual) ...[
            _sectionTitle('Configuración Manual de Límites'),
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Frecuencia Cardíaca (BPM)', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildManualField('Mín. Normal', _bpmMinNormalCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildManualField('Máx. Normal', _bpmMaxNormalCtrl)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildManualField('Mín. Moderado', _bpmMinModerateCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildManualField('Máx. Moderado', _bpmMaxModerateCtrl)),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  const Text('Oxígeno (SpO₂ %)', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildManualField('Mín. Normal', _spo2MinNormalCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildManualField('Mín. Moderado', _spo2MinModerateCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildManualField('Mín. Crítico', _spo2MinCriticalCtrl)),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            _sectionTitle('Umbrales Calculados (Solo Lectura)'),
            _thresholdInfoRow('Normal', const Color(0xFF10B981), 'BPM: ${_bpmMinNormalCtrl.text} – ${_bpmMaxNormalCtrl.text}', 'SpO₂: ≥ ${_spo2MinNormalCtrl.text}%'),
            const SizedBox(height: 10),
            _thresholdInfoRow('Moderado', const Color(0xFFF59E0B), 'BPM: ${_bpmMinModerateCtrl.text} – ${_bpmMaxModerateCtrl.text}', 'SpO₂: ${_spo2MinModerateCtrl.text}% – ${_spo2MinNormalCtrl.text}%'),
            const SizedBox(height: 10),
            _thresholdInfoRow('Crítico', const Color(0xFFDC2626), 'BPM: < ${_bpmMinModerateCtrl.text} o > ${_bpmMaxModerateCtrl.text}', 'SpO₂: < ${_spo2MinCriticalCtrl.text}%'),
          ],

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSaving ? null : _saveThresholds,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, color: Colors.white),
              label: Text(_isSaving ? 'Guardando...' : 'Guardar Umbrales', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: child,
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, String suffix, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const Spacer(),
        SizedBox(
          width: 90,
          height: 40,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              suffixText: ' $suffix',
              suffixStyle: const TextStyle(color: Colors.white54, fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              filled: true,
              fillColor: const Color(0xFF0A0E1A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              filled: true,
              fillColor: const Color(0xFF0A0E1A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
        ),
      ],
    );
  }

  Widget _thresholdInfoRow(String label, Color color, String bpmRange, String spo2Range) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: color.withOpacity(0.2),
            child: Icon(Icons.circle, color: color, size: 8),
          ),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(bpmRange, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 2),
              Text(spo2Range, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4))),
        ],
      ),
    );
  }
}
