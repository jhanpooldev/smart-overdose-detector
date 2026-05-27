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
import '../../domain/models/iot_session_model.dart';
import '../../infrastructure/api_client/api_client.dart';
import '../../infrastructure/auth/auth_service.dart';
import '../../infrastructure/sensors/simulated_sensor/simulated_sensor_adapter.dart';
import '../../infrastructure/telemetry/telemetry_service.dart';

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
  final TelemetryService _telemetry = TelemetryService();
  final SimulatedSensorAdapter _sensor = SimulatedSensorAdapter();
  final ApiClient _api = ApiClient();

  // ── Estado de sesión ──────────────────────────────────────────────────────
  IoTSessionModel? _session;
  StreamConnectionState _connectionState = StreamConnectionState.disconnected;

  // ── Datos en tiempo real ──────────────────────────────────────────────────
  BiometricSignalResponse? _latest;
  final List<FlSpot> _bpmSeries  = [];
  final List<FlSpot> _spo2Series = [];
  int _tickIndex = 0;

  // ── Animaciones ───────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  // ── Suscripciones ─────────────────────────────────────────────────────────
  StreamSubscription<dynamic>? _signalSub;
  StreamSubscription<dynamic>? _stateSub;
  StreamSubscription<dynamic>? _sensorSub;

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
    // Escuchar estado de conexión
    _stateSub = _telemetry.connectionStateStream.listen((event) {
      if (mounted) setState(() => _connectionState = event.state);
    });

    // Escuchar señales procesadas por el backend
    _signalSub = _telemetry.signalStream.listen(_onSignalReceived);

    // Iniciar sesión IoT
    try {
      final session = await _telemetry.startSession();
      if (mounted) setState(() => _session = session);
    } catch (e) {
      debugPrint('Error iniciando sesión IoT: $e');
    }

    // Conectar sensor simulado → enviar vía TelemetryService
    _sensorSub = _sensor.biometricStream.listen(_onSensorReading);
  }

  // ── Callback: lectura del sensor simulado ─────────────────────────────────
  void _onSensorReading(dynamic rawReading) {
    // Enviar al backend a través del TelemetryService
    _telemetry.sendReading(
      heartRate: rawReading.bpm as int,
      spo2:      (rawReading.spo2 as double).round(),
      statusMovement: rawReading.activity == 1 ? 'WALKING' : 'STILL',
    );
  }

  // ── Callback: señal procesada por el backend ──────────────────────────────
  void _onSignalReceived(BiometricSignalResponse signal) {
    if (!mounted) return;

    setState(() {
      _latest = signal;
      _tickIndex++;

      // Mantener ventana deslizante de _kChartWindowSize puntos
      _bpmSeries.add(FlSpot(_tickIndex.toDouble(), signal.heartRate.toDouble()));
      _spo2Series.add(FlSpot(_tickIndex.toDouble(), signal.spo2.toDouble()));

      if (_bpmSeries.length > _kChartWindowSize) {
        _bpmSeries.removeAt(0);
        _spo2Series.removeAt(0);
      }
    });

    // Disparar alertas si es crítico (RF06)
    if (signal.riskLevel == RiskLevelV2.critical) {
      _handleCriticalAlert(signal);
    } else {
      _resetAlertFlags();
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
    _signalSub?.cancel();
    _stateSub?.cancel();
    _sensorSub?.cancel();
    _pulseCtrl.dispose();
    _alertReset?.cancel();
    _sensor.stopSimulation();
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
          if (_session != null) _buildTokenBanner(),
          _buildScenarioBar(),
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
    final isConnected = _connectionState == StreamConnectionState.connected;
    final isError     = _connectionState == StreamConnectionState.error;
    Color color = isConnected
        ? const Color(0xFF10B981)
        : isError
            ? const Color(0xFFEF4444)
            : const Color(0xFFF59E0B);
    String label = switch (_connectionState) {
      StreamConnectionState.connected    => '● Transmitiendo en tiempo real',
      StreamConnectionState.connecting   => '○ Conectando...',
      StreamConnectionState.error        => '✕ Error de conexión',
      StreamConnectionState.disconnected => '○ Desconectado',
    };

    return Container(
      color: color.withOpacity(0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            color: color, size: 14,
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTokenBanner() => Container(
    color: const Color(0xFF0D1220),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(
      children: [
        const Icon(Icons.key_rounded, color: Color(0xFF6B7280), size: 13),
        const SizedBox(width: 6),
        Text(
          'Token IoT: ${_session!.sessionToken}',
          style: const TextStyle(
            color: Color(0xFF60A5FA),
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const Spacer(),
        if (_session!.timeRemaining != null)
          Text(
            'Expira en ${_session!.timeRemaining!.inHours}h',
            style: const TextStyle(color: Color(0xFF4B5563), fontSize: 10),
          ),
      ],
    ),
  );

  Widget _buildScenarioBar() => Container(
    color: const Color(0xFF0D1220),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const Text('Simular:', style: TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
          const SizedBox(width: 8),
          _scenarioBtn('Normal', ScenarioType.normal, const Color(0xFF10B981)),
          const SizedBox(width: 6),
          _scenarioBtn('Moderado', ScenarioType.moderate, const Color(0xFFF59E0B)),
          const SizedBox(width: 6),
          _scenarioBtn('Crítico', ScenarioType.critical, const Color(0xFFEF4444)),
        ],
      ),
    ),
  );

  Widget _scenarioBtn(String label, ScenarioType type, Color color) => InkWell(
    onTap: () => _sensor.setScenario(type),
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    ),
  );

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
      )),
    ],
  );

  Widget _metricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
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
      ],
    ),
  );

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
