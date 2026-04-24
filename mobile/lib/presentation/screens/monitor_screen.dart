// lib/presentation/screens/monitor_screen.dart
// Pantalla 1 (❤️) — Monitoreo en tiempo real. Se convierte en ALERTA CRÍTICA cuando el riesgo es alto.
import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/entities/biometric_reading.dart';
import '../../domain/entities/risk_prediction.dart';
import '../../infrastructure/sensors/simulated_sensor/simulated_sensor_adapter.dart';
import '../../infrastructure/auth/auth_service.dart';
import '../../domain/entities/user.dart';

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

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _sensor.biometricStream.listen(_onReading);
  }

  void _onReading(BiometricReading r) {
    setState(() {
      _reading = r;
      _risk = _classify(r);
    });
  }

  RiskLevel _classify(BiometricReading r) {
    if (r.spo2 < 82 || r.bpm < 50) return RiskLevel.critical;
    if (r.spo2 < 90 || r.bpm < 60) return RiskLevel.moderate;
    return RiskLevel.normal;
  }

  @override
  void dispose() {
    _sensor.stopSimulation();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCritical = _risk == RiskLevel.critical;
    final isDoctor = AuthService().currentUser?.role == Role.doctor;
    final user = AuthService().currentUser;

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
          if (isDoctor)
            PopupMenuButton<ScenarioType>(
              icon: const Icon(Icons.tune, color: Colors.white),
              color: Colors.white,
              tooltip: 'Cambiar escenario (Doctor)',
              onSelected: (s) => _sensor.setScenario(s),
              itemBuilder: (_) => [
                const PopupMenuItem(value: ScenarioType.normal, child: Text('🟢 Normal')),
                const PopupMenuItem(value: ScenarioType.moderate, child: Text('🟡 Moderado')),
                const PopupMenuItem(value: ScenarioType.critical, child: Text('🔴 Crítico')),
              ],
            ),
        ],
      ),
      body: _reading == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : isCritical
              ? _buildCriticalView(_reading!)
              : _buildNormalView(_reading!),
    );
  }

  Widget _buildNormalView(BiometricReading r) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
          onPressed: () {},
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
          onPressed: () {},
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
    final (text, color) = switch (_risk) {
      RiskLevel.normal => ('Estado: Normal', const Color(0xFF10B981)),
      RiskLevel.moderate => ('Estado: Riesgo Moderado', const Color(0xFFF59E0B)),
      RiskLevel.critical => ('Estado: Riesgo Crítico', const Color(0xFFDC2626)),
    };
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
              TextSpan(text: value, style: TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: color)),
              TextSpan(text: ' $unit', style: TextStyle(fontSize: 22, color: color, fontWeight: FontWeight.w500)),
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
