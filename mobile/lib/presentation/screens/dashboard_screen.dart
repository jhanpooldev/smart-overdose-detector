// lib/presentation/screens/dashboard_screen.dart
// Dashboard principal — monitoreo biométrico en tiempo real (PMV1)

import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/entities/biometric_reading.dart';
import '../../domain/entities/risk_prediction.dart';
import '../../infrastructure/sensors/simulated_sensor/simulated_sensor_adapter.dart';
import '../widgets/simulation_badge.dart';
import '../widgets/vitals_card.dart';
import '../widgets/risk_level_chip.dart';
import 'historial_screen.dart';
import 'configuracion_screen.dart';
import 'login_screen.dart';
import '../../domain/entities/user.dart';
import '../../infrastructure/auth/auth_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final SimulatedSensorAdapter _sensorAdapter = SimulatedSensorAdapter();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  BiometricReading? _lastReading;
  RiskLevel _currentRiskLevel = RiskLevel.normal;
  bool _alertShown = false;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _sensorAdapter.biometricStream.listen(_onNewReading);
  }

  void _onNewReading(BiometricReading reading) {
    final risk = _classifyRisk(reading);
    setState(() {
      _lastReading = reading;
      _currentRiskLevel = risk;
    });
    if (risk == RiskLevel.critical && !_alertShown) {
      _alertShown = true;
      Future.delayed(const Duration(milliseconds: 300), () => _showCriticalAlert(reading));
    } else if (risk != RiskLevel.critical) {
      _alertShown = false;
    }
  }

  RiskLevel _classifyRisk(BiometricReading r) {
    if (r.spo2 < 82 || r.bpm < 50) return RiskLevel.critical;
    if (r.spo2 < 90 || r.bpm < 60) return RiskLevel.moderate;
    return RiskLevel.normal;
  }

  void _showCriticalAlert(BiometricReading reading) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CriticalAlertDialog(reading: reading),
    ).then((_) => _alertShown = false);
  }

  @override
  void dispose() {
    _sensorAdapter.stopSimulation();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildBody(),
          const Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(child: SimulationBadge()),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  AppBar _buildAppBar() {
    final user = AuthService().currentUser;
    final isDoctor = user?.role == Role.doctor;
    final roleLabel = user?.role.name.toUpperCase() ?? 'PACIENTE';
    
    return AppBar(
      backgroundColor: const Color(0xFF0D1220),
      elevation: 0,
      centerTitle: true,
      title: Column(
        children: [
          const Text(
            'Smart Overdose Detector',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            'Monitoreo — Perfil: \$roleLabel',
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
        ],
      ),
      actions: [
        if (isDoctor)
          PopupMenuButton<ScenarioType>(
            icon: const Icon(Icons.tune, color: Color(0xFF60A5FA)),
            tooltip: 'Cambiar escenario',
            color: const Color(0xFF1A2035),
            onSelected: (s) => setState(() => _sensorAdapter.setScenario(s)),
            itemBuilder: (_) => [
              _scenarioItem(ScenarioType.normal, '🟢 Normal', const Color(0xFF10B981)),
              _scenarioItem(ScenarioType.moderate, '🟡 Moderado', const Color(0xFFF59E0B)),
              _scenarioItem(ScenarioType.critical, '🔴 Crítico', const Color(0xFFEF4444)),
            ],
          ),
        IconButton(
          icon: const Icon(Icons.logout, color: Color(0xFFEF4444)),
          onPressed: () {
            AuthService().logout();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
        ),
      ],
    );
  }

  PopupMenuItem<ScenarioType> _scenarioItem(ScenarioType val, String label, Color color) {
    final isSelected = _sensorAdapter.currentScenario == val;
    return PopupMenuItem(
      value: val,
      child: Row(
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          if (isSelected) ...[
            const Spacer(),
            const Icon(Icons.check, size: 16, color: Color(0xFF60A5FA)),
          ]
        ],
      ),
    );
  }

  Widget _buildBody() {
    return IndexedStack(
      index: _selectedTab,
      children: [
        _buildDashboardTab(),
        const HistorialScreen(),
        const ConfiguracionScreen(),
      ],
    );
  }

  Widget _buildDashboardTab() {
    final r = _lastReading;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 64, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Risk Level Banner
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: _currentRiskLevel == RiskLevel.critical ? _pulseAnim.value : 1.0,
              child: child,
            ),
            child: RiskLevelChip(level: _currentRiskLevel),
          ),
          const SizedBox(height: 20),

          // Vital Signs Cards
          if (r != null) ...[
            VitalsCard(
              label: 'Saturación de Oxígeno',
              value: '${r.spo2.toStringAsFixed(1)}%',
              icon: Icons.water_drop_rounded,
              color: r.spo2 < 82
                  ? const Color(0xFFEF4444)
                  : r.spo2 < 90
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF60A5FA),
              subtitle: r.spo2 < 82
                  ? '⚠️ Hipoxemia crítica'
                  : r.spo2 < 90
                      ? '⚠️ Hipoxemia leve'
                      : '✓ Normal',
              progress: (r.spo2 - 70) / 30,
            ),
            const SizedBox(height: 12),
            VitalsCard(
              label: 'Frecuencia Cardíaca',
              value: '${r.bpm} BPM',
              icon: Icons.favorite_rounded,
              color: r.bpm < 50
                  ? const Color(0xFFEF4444)
                  : r.bpm < 60 || r.bpm > 100
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFEC4899),
              subtitle: r.bpm < 50
                  ? '⚠️ Bradicardia severa'
                  : r.bpm < 60
                      ? '⚠️ Bradicardia'
                      : r.bpm > 100
                          ? '⚠️ Taquicardia'
                          : '✓ Normal (60–100)',
              progress: (r.bpm.clamp(30, 180) - 30) / 150,
            ),
            const SizedBox(height: 12),
            VitalsCard(
              label: 'Nivel de Actividad',
              value: r.activity == 1 ? 'Activo' : 'En Reposo',
              icon: r.activity == 1 ? Icons.directions_run_rounded : Icons.bedtime_rounded,
              color: r.activity == 1
                  ? const Color(0xFF10B981)
                  : const Color(0xFF6B7280),
              subtitle: r.activity == 1 ? '✓ Movimiento detectado' : '— Sin movimiento',
              progress: r.activity.toDouble(),
            ),
            const SizedBox(height: 20),

            // Timestamp
            Center(
              child: Text(
                'Última lectura: ${_formatTime(r.timestamp)}',
                style: const TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 12,
                ),
              ),
            ),
          ] else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: Color(0xFF60A5FA)),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

  BottomNavigationBar _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedTab,
      backgroundColor: const Color(0xFF0D1220),
      selectedItemColor: const Color(0xFF60A5FA),
      unselectedItemColor: const Color(0xFF4B5563),
      type: BottomNavigationBarType.fixed,
      onTap: (i) => setState(() => _selectedTab = i),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.monitor_heart), label: 'Monitor'),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historial'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Config'),
      ],
    );
  }
}

// ─── Modal de Alerta Crítica ───────────────────────────────────────────────
class _CriticalAlertDialog extends StatelessWidget {
  final BiometricReading reading;
  const _CriticalAlertDialog({required this.reading});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A0A0A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.emergency, color: Color(0xFFEF4444), size: 32),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '🚨 ALERTA CRÍTICA',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Parámetros biométricos en zona de peligro:',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _alertRow('SpO₂', '${reading.spo2.toStringAsFixed(1)}%'),
          _alertRow('FC', '${reading.bpm} BPM'),
          _alertRow('Actividad', reading.activity == 0 ? 'Inmovilidad' : 'Activo'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEF4444), width: 1),
            ),
            child: const Row(
              children: [
                Icon(Icons.phone, color: Color(0xFFEF4444), size: 20),
                SizedBox(width: 8),
                Text(
                  'Llamar a Emergencias: 911',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Reconocer', style: TextStyle(color: Color(0xFF60A5FA))),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.phone, size: 18),
          label: const Text('Llamar 911'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _alertRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFEF4444),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
