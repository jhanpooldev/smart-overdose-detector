// lib/presentation/screens/monitor_screen.dart
// Pantalla 1 (❤️) — Monitoreo en tiempo real. Se convierte en ALERTA CRÍTICA cuando el riesgo es alto.
import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import '../../domain/entities/biometric_reading.dart';
import '../../domain/entities/risk_prediction.dart';
import '../../infrastructure/sensors/simulated_sensor/simulated_sensor_adapter.dart';
import '../../infrastructure/auth/auth_service.dart';
import '../../domain/entities/user.dart';
import 'package:permission_handler/permission_handler.dart';
import 'detail_status_screen.dart';
import 'alerta_screen.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> with TickerProviderStateMixin {
  final SimulatedSensorAdapter _sensor = SimulatedSensorAdapter();
  BiometricReading? _reading;
  RiskLevel _risk = RiskLevel.normal;
  late AnimationController _pulseCtrl;

  bool _isConnected = true;
  bool _isSensorPlaced = true;
  Timer? _alertTimer;
  bool _callMade = false; // Garantiza que la llamada se haga UNA sola vez por episodio crítico
  RiskLevel? _lastAlertSaved; // Evita guardar la misma alerta repetidamente

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _sensor.biometricStream.listen(_onReading);
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Pedir permiso de notificaciones y llamadas al inicio
    await [
      Permission.notification,
      Permission.phone,
    ].request();
  }

  void _onReading(BiometricReading r) {
    setState(() {
      _reading = r;
      _risk = _classify(r);
    });
    _pushReadingToBackend(r);
  }

  Future<void> _pushReadingToBackend(BiometricReading r) async {
    try {
      final auth = AuthService();
      if (auth.token == null) return;
      
      await http.post(
        Uri.parse('${auth.baseUrl.replaceAll('/auth', '')}/readings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${auth.token}',
        },
        body: jsonEncode({
          'patient_id': auth.currentUser!.id,
          'spo2': r.spo2,
          'bpm': r.bpm,
          'activity': r.activity,
        }),
      );
    } catch (_) {}
  }

  RiskLevel _classify(BiometricReading r) {
    if (r.spo2 < 82 || r.bpm < 50) return RiskLevel.critical;
    if (r.spo2 < 90 || r.bpm < 60) return RiskLevel.moderate;
    return RiskLevel.normal;
  }

  Future<void> _triggerAlert() async {
    if (_risk != RiskLevel.normal && _isConnected && _isSensorPlaced) {
      if (_risk == RiskLevel.critical && !_callMade) {
        _callMade = true; // Bloquea llamadas futuras para este episodio
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Alerta Crítica - Llamando a emergencias'),
              backgroundColor: Color(0xFFDC2626),
              duration: Duration(seconds: 3),
            ),
          );
        }
        await _makeEmergencyCall();
      }
      // Guardar alerta solo si cambió el nivel desde la última vez
      if (_lastAlertSaved != _risk) {
        _lastAlertSaved = _risk;
        await _saveAlertToBackend(_risk);
      }
    }
  }

  Future<void> _makeEmergencyCall() async {
    // Intentar llamar directamente al supervisor o número de emergencia
    const number = '999999999'; // Dummy number para el PMV
    bool? res = await FlutterPhoneDirectCaller.callNumber(number);
    if (res == false && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo realizar la llamada automática')),
      );
    }
  }

  Future<void> _saveAlertToBackend(RiskLevel risk) async {
    if (_reading == null) return;
    try {
      final auth = AuthService();
      await http.post(
        Uri.parse('${auth.baseUrl.replaceAll('/auth', '')}/alerts/save'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${auth.token}',
        },
        body: jsonEncode({
          'patient_id': auth.currentUser!.id,
          'risk_level': risk.name,
          'spo2': _reading!.spo2,
          'bpm': _reading!.bpm,
        }),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _sensor.stopSimulation();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCritical = _risk == RiskLevel.critical && _isConnected && _isSensorPlaced;
    final isSupervisor = AuthService().currentUser?.role == Role.supervisor;
    final user = AuthService().currentUser;

    if (isCritical && (_alertTimer == null || !_alertTimer!.isActive)) {
      _alertTimer = Timer.periodic(const Duration(seconds: 5), (_) => _triggerAlert());
      // Disparar inmediatamente la primera vez
      Future.microtask(() => _triggerAlert());
    } else if (!isCritical) {
      if (_alertTimer?.isActive == true) {
        _alertTimer?.cancel();
        // Resetear flags al volver a estado no-crítico
        _callMade = false;
        _lastAlertSaved = null;
      }
    }

    return Scaffold(
      backgroundColor: isCritical ? const Color(0xFFFEF2F2) : const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: isCritical ? const Color(0xFFDC2626) : const Color(0xFF1D4ED8),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCritical) ...[
              const Icon(Icons.warning_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              const Text('ALERTA CRÍTICA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ] else ...[
              const Icon(Icons.monitor_heart, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              const Text('Monitor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AlertaScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection & Sensor Status Bar
          Container(
            color: _isConnected ? const Color(0xFFE0F2FE) : const Color(0xFFFEE2E2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: _isConnected ? const Color(0xFF0369A1) : const Color(0xFFB91C1C),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isConnected ? 'conectado' : 'desconectado',
                      style: TextStyle(
                        color: _isConnected ? const Color(0xFF0369A1) : const Color(0xFFB91C1C),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Simular fallos:', style: TextStyle(fontSize: 10, color: Colors.black54)),
                    const SizedBox(width: 4),
                    Switch(
                      value: _isConnected,
                      onChanged: (v) => setState(() => _isConnected = v),
                      activeColor: const Color(0xFF0369A1),
                    ),
                    Switch(
                      value: _isSensorPlaced,
                      onChanged: (v) => setState(() => _isSensorPlaced = v),
                      activeColor: const Color(0xFF10B981),
                    ),
                  ],
                )
              ],
            ),
          ),
          if (!isSupervisor)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                    onPressed: () => _sensor.setScenario(ScenarioType.normal),
                    child: const Text('Leve (Normal)', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
                    onPressed: () => _sensor.setScenario(ScenarioType.moderate),
                    child: const Text('Moderado', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                    onPressed: () => _sensor.setScenario(ScenarioType.critical),
                    child: const Text('Crítico', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
            ),
          if (!_isConnected)
            _buildErrorView('dispositivo apagado', '-En espera-', 'Estado: Sin datos')
          else if (!_isSensorPlaced)
            _buildErrorView('no se está recibiendo datos, por favor asegurate que el dispositivo esté bien colocado', '-', 'Estado: Sin datos')
          else if (_reading == null)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))))
          else
            Expanded(
              child: isCritical ? _buildCriticalView(_reading!) : _buildNormalView(_reading!),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String message, String valueStr, String statusText) {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(color: const Color(0xFF6B7280).withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF6B7280).withOpacity(0.3))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.circle, color: Color(0xFF6B7280), size: 10),
              const SizedBox(width: 8),
              Text(statusText, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
                const SizedBox(width: 12),
                Expanded(child: Text(message, style: const TextStyle(color: Color(0xFF991B1B)))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _bigMetricCard(
            label: 'Frecuencia cardíaca:',
            value: valueStr,
            unit: '',
            color: const Color(0xFF9CA3AF),
            icon: Icons.favorite_border,
          ),
        ],
      ),
    );
  }

  Widget _buildNormalView(BiometricReading r) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Center(
          child: Text('Recibiendo datos', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        // Status badge
        _statusBadge(),
        const SizedBox(height: 16),

        // BPM Card — main metric
        _bigMetricCard(
          label: 'Frecuencia cardíaca:',
          value: '${r.bpm}',
          unit: 'BPM',
          color: _bpmColor(r.bpm),
          icon: Icons.favorite_rounded,
        ),
        const SizedBox(height: 12),

        // SpO2
        _smallMetricCard('Saturación (SpO₂)', '${r.spo2.toStringAsFixed(1)}%', Icons.water_drop_rounded, _spo2Color(r.spo2)),
        const SizedBox(height: 12),

        // Activity
        _smallMetricCard(
          'Estado del sensor',
          r.activity == 1 ? 'Activo' : 'Reposo',
          r.activity == 1 ? Icons.directions_run_rounded : Icons.bedtime_rounded,
          r.activity == 1 ? const Color(0xFF10B981) : const Color(0xFF6B7280),
        ),
        const SizedBox(height: 12),

        OutlinedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DetailStatusScreen()),
            );
          },
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF2563EB)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text('Ver estado detallado >', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildCriticalView(BiometricReading r) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        // BPM central
        _bigMetricCard(
          label: 'Frecuencia cardíaca:',
          value: '${r.bpm}',
          unit: 'BPM',
          color: const Color(0xFFDC2626),
          icon: Icons.favorite_rounded,
        ),
        const SizedBox(height: 16),

        // Estado Riesgo Crítico pill
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text('Estado: Riesgo Crítico', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 16),

        const Center(
          child: Text('Posible sobredosis detectada', style: TextStyle(color: Color(0xFF4B5563), fontSize: 14)),
        ),
        const SizedBox(height: 24),

        // Comunicándose card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.wifi_calling_3_rounded, size: 40, color: Color(0xFF2563EB)),
                const SizedBox(height: 8),
                const Text('Comunicándose con\ncontactos de emergencia...', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF4B5563), fontSize: 13)),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlertaScreen()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.history, color: Colors.white),
          label: const Text('Historial', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
        ),
      ],
    );
  }

  Widget _statusBadge() {
    String text;
    Color color;

    if (_risk == RiskLevel.normal) {
      text = 'Estado: Normal';
      color = const Color(0xFF10B981);
    } else if (_risk == RiskLevel.moderate) {
      text = 'Estado: Bajo'; // As per PMV HU-005, we display Bajo/Alto instead of moderate/critical in text
      color = const Color(0xFFF59E0B);
    } else {
      text = 'Estado: Alto';
      color = const Color(0xFFDC2626);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.circle, color: color, size: 10),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ]),
    );
  }

  Widget _bigMetricCard({required String label, required String value, required String unit, required Color color, required IconData icon}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13))]),
            const SizedBox(height: 8),
            RichText(text: TextSpan(children: [
              TextSpan(text: value, style: TextStyle(fontSize: value.length > 5 ? 32 : 56, fontWeight: FontWeight.bold, color: color)),
              if (unit.isNotEmpty) TextSpan(text: ' $unit', style: TextStyle(fontSize: 22, color: color, fontWeight: FontWeight.w500)),
            ])),
          ],
        ),
      ),
    );
  }

  Widget _smallMetricCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 28),
        title: Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
        trailing: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Color _bpmColor(int bpm) {
    if (bpm < 50 || bpm > 120) return const Color(0xFFDC2626);
    if (bpm < 60) return const Color(0xFFF59E0B);
    return const Color(0xFF2563EB);
  }

  Color _spo2Color(double spo2) {
    if (spo2 < 82) return const Color(0xFFDC2626);
    if (spo2 < 90) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }
}
