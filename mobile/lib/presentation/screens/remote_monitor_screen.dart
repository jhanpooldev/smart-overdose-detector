// lib/presentation/screens/remote_monitor_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../infrastructure/auth/auth_service.dart';
import 'historial_screen.dart';
import 'umbrales_screen.dart';

class RemoteMonitorScreen extends StatefulWidget {
  final String patientId;
  final String patientEmail;

  const RemoteMonitorScreen({super.key, required this.patientId, required this.patientEmail});

  @override
  State<RemoteMonitorScreen> createState() => _RemoteMonitorScreenState();
}

class _RemoteMonitorScreenState extends State<RemoteMonitorScreen> {
  Timer? _pollingTimer;
  Map<String, dynamic>? _reading;
  bool _isLoading = true;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _fetchLatestReading();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _fetchLatestReading();
    });
  }

  Future<void> _fetchLatestReading() async {
    if (!mounted) return;
    try {
      final auth = AuthService();
      final url = '${auth.baseUrl.replaceAll('/auth', '')}/readings/${widget.patientId}/latest';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _reading = jsonDecode(response.body);
            _isLoading = false;
            _isConnected = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isConnected = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monitoreo Remoto', style: TextStyle(fontSize: 11, color: Colors.white54)),
            const SizedBox(height: 2),
            Text(widget.patientEmail, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            tooltip: 'Ver Historial',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HistorialScreen(
                    patientId: widget.patientId,
                    patientLabel: widget.patientEmail,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            tooltip: 'Ajustar Umbrales',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UmbralesScreen(patientId: widget.patientId)),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Translucent connection bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _isConnected ? const Color(0xFF10B981).withOpacity(0.08) : const Color(0xFFEF4444).withOpacity(0.08),
              border: Border(
                bottom: BorderSide(
                  color: _isConnected ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFFEF4444).withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: _isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _isConnected ? const Color(0xFF10B981).withOpacity(0.6) : const Color(0xFFEF4444).withOpacity(0.6),
                        blurRadius: 6,
                        spreadRadius: 2,
                      )
                    ]
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _isConnected ? 'PACIENTE EN LÍNEA - RECIBIENDO TELEMETRÍA' : 'PACIENTE SIN CONEXIÓN - ESPERANDO DATOS',
                  style: TextStyle(
                    color: _isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))))
          else if (!_isConnected || _reading == null)
            _buildErrorView('No se están recibiendo signos vitales de este paciente.', 'Sin datos')
          else
            Expanded(
              child: _buildMonitorContent(_reading!),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String message, String valueStr) {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          _statusBadge('offline'),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131929),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _bigMetricCard(
            label: 'Último Pulso Registrado',
            value: valueStr,
            unit: '',
            color: Colors.white30,
            icon: Icons.favorite_border_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildMonitorContent(Map<String, dynamic> r) {
    final riskLevel = r['risk_level'] as String?;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _statusBadge(riskLevel),
        const SizedBox(height: 20),
        _bigMetricCard(
          label: 'Frecuencia Cardíaca',
          value: '${r['bpm']}',
          unit: 'BPM',
          color: _bpmColor(r['bpm']),
          icon: Icons.favorite_rounded,
        ),
        const SizedBox(height: 16),
        _smallMetricCard(
          'Saturación de Oxígeno (SpO₂)',
          '${r['spo2']?.toStringAsFixed(1)}%',
          Icons.water_drop_rounded,
          _spo2Color(r['spo2']),
        ),
        if (riskLevel == 'critical') ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.emergency_rounded, color: Color(0xFFEF4444), size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'ATENCIÓN: PACIENTE EN RIESGO DE SOBREDOSIS',
                    style: TextStyle(color: Color(0xFFFCA5A5), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _statusBadge(String? riskLevel) {
    String text;
    Color color;

    if (riskLevel == 'normal') {
      text = 'ESTADO DEL PACIENTE: NORMAL';
      color = const Color(0xFF10B981);
    } else if (riskLevel == 'moderate') {
      text = 'ESTADO DEL PACIENTE: MODERADO';
      color = const Color(0xFFF59E0B);
    } else if (riskLevel == 'critical') {
      text = 'ESTADO DEL PACIENTE: CRÍTICO';
      color = const Color(0xFFEF4444);
    } else {
      text = 'PACIENTE SIN CONEXIÓN';
      color = Colors.white30;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.circle, color: color, size: 8),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _bigMetricCard({required String label, required String value, required String unit, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            textBaseline: TextBaseline.alphabetic,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: color, height: 1),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  unit,
                  style: TextStyle(fontSize: 20, color: color.withOpacity(0.7), fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Color _bpmColor(int bpm) {
    if (bpm < 50 || bpm > 120) return const Color(0xFFEF4444);
    if (bpm < 60) return const Color(0xFFF59E0B);
    return const Color(0xFF2563EB);
  }

  Color _spo2Color(dynamic spo2) {
    final val = (spo2 is int) ? spo2.toDouble() : spo2 as double;
    if (val < 82) return const Color(0xFFEF4444);
    if (val < 90) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }
}
