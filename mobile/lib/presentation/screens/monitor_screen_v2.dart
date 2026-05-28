// lib/presentation/screens/monitor_screen_v2.dart
//
// Pantalla de monitoreo PMV2 — Gráficos de series temporales en tiempo real (RF05/RF10).
// Conecta al TelemetryService y muestra BPM + SpO2 con fl_chart.
// Gestiona permisos asíncronos (RF06) y estado de conexión IoT (RF08).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

import '../../domain/models/biometric_signal_model.dart';
import '../../infrastructure/api_client/api_client.dart';
import '../../infrastructure/auth/auth_service.dart';

/// Número de puntos visibles en el gráfico de series temporales.
const int _kChartWindowSize = 30;

class MonitorScreenV2 extends StatefulWidget {
  const MonitorScreenV2({super.key});

  @override
  State<MonitorScreenV2> createState() => _MonitorScreenV2State();
}

class _MonitorScreenV2State extends State<MonitorScreenV2>
    with TickerProviderStateMixin {
  // ── Servicios ─────────────────────────────────────────────────────────────
  final ApiClient _api = ApiClient();
  Timer? _pollingTimer;

  // ── Estado de conexión ──────────────────────────────────────────────────────
  bool _isConnected = false;

  // ── Datos en tiempo real ──────────────────────────────────────────────────
  BiometricSignalResponse? _latest;
  final List<FlSpot> _bpmSeries  = [];
  final List<FlSpot> _spo2Series = [];
  int _tickIndex = 0;

  // ── Animaciones ───────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  // ── Suscripciones ─────────────────────────────────────────────────────────

  // ── Flags de alerta ───────────────────────────────────────────────────────
  bool _callMade   = false;
  bool _smsSent    = false;
  Timer? _alertReset;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _requestPermissions().then((_) => _initTelemetry());
  }

  // ── Permisos asíncronos (RF06) ────────────────────────────────────────────
  Future<void> _requestPermissions() async {
    await [
      Permission.notification,
      Permission.phone,
      Permission.sms,
    ].request();
  }

  // ── Inicializar sesión IoT y streams ──────────────────────────────────────
  Future<void> _initTelemetry() async {
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchLatestData());
    _fetchLatestData();
  }

  Future<void> _fetchLatestData() async {
    try {
      final userId = AuthService().currentUser?.id ?? '';
      if (userId.isEmpty) return;
      
      final history = await _api.getSignalHistory(patientId: userId, limit: _kChartWindowSize);
      if (!mounted) return;

      if (history.isEmpty) {
        setState(() => _isConnected = false);
        return;
      }

      // Comprobar si el último dato es reciente (menos de 1 minuto)
      final latest = history.first;
      final isRecent = DateTime.now().toUtc().difference(latest.time.toUtc()).inSeconds < 60;

      setState(() {
        _isConnected = isRecent;
        _latest = latest;
        
        // Reconstruir gráficos
        _bpmSeries.clear();
        _spo2Series.clear();
        
        // La API devuelve los más recientes primero, así que invertimos para el gráfico
        final reversed = history.reversed.toList();
        for (int i = 0; i < reversed.length; i++) {
          _bpmSeries.add(FlSpot(i.toDouble(), reversed[i].heartRate.toDouble()));
          _spo2Series.add(FlSpot(i.toDouble(), reversed[i].spo2.toDouble()));
        }
      });

      if (latest.riskLevel == RiskLevelV2.critical && isRecent) {
        _handleCriticalAlert(latest);
      } else {
        _resetAlertFlags();
      }
    } catch (e) {
      if (mounted) setState(() => _isConnected = false);
    }
  }

  // ── Lógica de alerta crítica (RF06) ──────────────────────────────────────
  void _handleCriticalAlert(BiometricSignalResponse signal) {
    if (!_callMade) {
      _callMade = true;
      _makeEmergencyCall();
    }
    if (!_smsSent) {
      _smsSent = true;
      _sendEmergencySms(signal);
    }
  }

  Future<void> _makeEmergencyCall() async {
    try {
      final contacts = await _api.getContacts();
      if (contacts.isEmpty) return;

      // Llamar al primer contacto (mayor prioridad)
      final phone = contacts.first['telefono'] as String? ?? '';
      if (phone.isNotEmpty) {
        await FlutterPhoneDirectCaller.callNumber(phone);
      }
    } catch (e) {
      debugPrint('Error en llamada de emergencia: $e');
    }
  }

  Future<void> _sendEmergencySms(BiometricSignalResponse signal) async {
    try {
      final status = await Permission.sms.status;
      if (!status.isGranted) return;

      final contacts = await _api.getContacts();
      if (contacts.isEmpty) return;

      // SMS a todos los contactos excepto el primero (que recibe la llamada)
      final others = contacts.skip(1).map((c) => c['telefono'] as String? ?? '').where((p) => p.isNotEmpty).toList();
      if (others.isEmpty) return;

      final body = Uri.encodeComponent(
        'ALERTA CRÍTICA — Smart Overdose Detector\n'
        'SpO₂: ${signal.spo2}% | FC: ${signal.heartRate} BPM\n'
        '${signal.clinicalSuggestion}\n'
        'Hora: ${_formatTime(signal.time)}',
      );
      final smsUri = Uri.parse('sms:${others.join(",")}?body=$body');
      if (await canLaunchUrl(smsUri)) await launchUrl(smsUri);
    } catch (e) {
      debugPrint('Error enviando SMS: $e');
    }
  }

  void _resetAlertFlags() {
    _alertReset?.cancel();
    _alertReset = Timer(const Duration(minutes: 5), () {
      _callMade = false;
      _smsSent  = false;
    });
  }

  // ── Dispose ───────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pulseCtrl.dispose();
    _alertReset?.cancel();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isCritical = _latest?.riskLevel == RiskLevelV2.critical;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: _buildAppBar(isCritical),
      body: Column(
        children: [
          _buildConnectionBar(),
          Expanded(child: _buildBody(isCritical)),
        ],
      ),
    );
  }

  AppBar _buildAppBar(bool isCritical) => AppBar(
    backgroundColor: isCritical ? const Color(0xFF7F1D1D) : const Color(0xFF0D1220),
    elevation: 0,
    title: AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) => Transform.scale(
        scale: isCritical ? _pulseAnim.value : 1.0,
        child: child,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCritical ? Icons.warning_rounded : Icons.monitor_heart_rounded,
            color: isCritical ? const Color(0xFFEF4444) : const Color(0xFF60A5FA),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            isCritical ? '🚨 ALERTA CRÍTICA' : 'Monitor PMV2',
            style: TextStyle(
              color: isCritical ? const Color(0xFFEF4444) : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.notifications_none_rounded, color: Colors.white70),
        onPressed: () {}, // Navegar a AlertaScreen
      ),
    ],
  );

  Widget _buildConnectionBar() {
    Color color = _isConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    String label = _isConnected ? '● Transmitiendo en tiempo real' : '○ Esperando dispositivo...';

    return Container(
      color: color.withOpacity(0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(
            _isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            color: color, size: 14,
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }



  Widget _buildBody(bool isCritical) {
    if (_latest == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF60A5FA)));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Métricas principales ─────────────────────────────────────────
        _buildMetricRow(),
        const SizedBox(height: 20),

        // ── Gráfico BPM (serie temporal) ─────────────────────────────────
        _buildChartCard(
          title: 'Frecuencia Cardíaca',
          series: _bpmSeries,
          color: const Color(0xFFEC4899),
          minY: 30, maxY: 180, unit: 'BPM',
        ),
        const SizedBox(height: 12),

        // ── Gráfico SpO2 (serie temporal) ────────────────────────────────
        _buildChartCard(
          title: 'Saturación de Oxígeno (SpO₂)',
          series: _spo2Series,
          color: const Color(0xFF60A5FA),
          minY: 70, maxY: 100, unit: '%',
        ),
        const SizedBox(height: 16),

        // ── Sugerencia clínica (RF13) ─────────────────────────────────────
        _buildClinicalSuggestion(),
      ],
    );
  }

  Widget _buildMetricRow() => Row(
    children: [
      Expanded(child: _metricCard(
        icon: Icons.favorite_rounded,
        label: 'BPM',
        value: '${_latest!.heartRate}',
        color: _latest!.riskLevel.color,
        onTapDetails: () => _showDetailsSheet('BPM (Frecuencia Cardíaca)', _latest!.heartRate.toDouble(), 'BPM', _latest!.riskLevel.color),
      )),
      const SizedBox(width: 12),
      Expanded(child: _metricCard(
        icon: Icons.water_drop_rounded,
        label: 'SpO₂',
        value: '${_latest!.spo2}%',
        color: _latest!.spo2 < 90
            ? const Color(0xFFEF4444)
            : _latest!.spo2 < 95
                ? const Color(0xFFF59E0B)
                : const Color(0xFF60A5FA),
        onTapDetails: () => _showDetailsSheet('SpO₂ (Saturación)', _latest!.spo2.toDouble(), '%', const Color(0xFF60A5FA)),
      )),
    ],
  );

  Widget _metricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTapDetails,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF0D1220),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(
          color: color, fontSize: 36, fontWeight: FontWeight.bold, height: 1,
        )),
        const SizedBox(height: 12),
        InkWell(
          onTap: onTapDetails,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ver más detalles', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded, color: color, size: 10),
            ],
          ),
        ),
      ],
    ),
  );

  void _showDetailsSheet(String title, double value, String unit, Color color) {
    String advice = '';
    String details = '';
    if (title.contains('BPM')) {
      details = 'La frecuencia cardíaca indica el número de latidos por minuto (BPM). Un rango normal en reposo es de 60 a 100 BPM.';
      if (value < 50) advice = '⚠️ Bradicardia severa detectada. Riesgo de depresión respiratoria inducida por opioides. Busque atención médica inmediata.';
      else if (value < 60) advice = 'ℹ️ Frecuencia ligeramente baja. Manténgase alerta si hay síntomas de somnolencia excesiva.';
      else if (value > 120) advice = '⚠️ Taquicardia. Ritmo cardíaco elevado, mantenga reposo y evalúe otras causas.';
      else advice = '✓ Frecuencia cardíaca dentro de los parámetros normales.';
    } else {
      details = 'La saturación de oxígeno (SpO₂) mide el porcentaje de oxígeno en la sangre. Un nivel normal es del 95% al 100%.';
      if (value < 90) advice = '⚠️ Hipoxemia severa detectada. Los opioides pueden causar que la respiración se vuelva peligrosamente lenta o se detenga. Requiere intervención médica inmediata.';
      else if (value < 95) advice = 'ℹ️ Nivel de oxígeno moderadamente bajo. Realice ejercicios de respiración profunda y mantenga vigilancia continua.';
      else advice = '✓ Saturación de oxígeno en niveles óptimos y saludables.';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131929),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: color),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Text('Lectura actual: ${value.toInt()}$unit', style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('¿Qué significa?', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(details, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
              child: Row(
                children: [
                  Icon(Icons.health_and_safety_rounded, color: color, size: 24),
                  const SizedBox(width: 12),
                  Expanded(child: Text(advice, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500))),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required List<FlSpot> series,
    required Color color,
    required double minY,
    required double maxY,
    required String unit,
  }) {
    if (series.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      height: 160,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: color.withOpacity(0.08), strokeWidth: 1),
                  getDrawingVerticalLine: (_) =>
                      FlLine(color: Colors.transparent),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}$unit',
                        style: const TextStyle(color: Color(0xFF4B5563), fontSize: 8),
                      ),
                    ),
                  ),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: series,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: color,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withOpacity(0.08),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 120),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalSuggestion() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _latest!.riskLevel.color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _latest!.riskLevel.color.withOpacity(0.25)),
    ),
    child: Row(
      children: [
        Icon(Icons.medical_information_rounded, color: _latest!.riskLevel.color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _latest!.clinicalSuggestion,
            style: TextStyle(color: _latest!.riskLevel.color, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
}
