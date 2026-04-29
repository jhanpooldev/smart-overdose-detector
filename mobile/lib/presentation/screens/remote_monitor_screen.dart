import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../infrastructure/auth/auth_service.dart';
import 'detail_status_screen.dart';

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
  bool _isConnected = true; // Simulating connection status to backend

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
        // Probablemente no hay lecturas aún o error 404
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
    final isCritical = _reading != null && _reading!['risk_level'] == 'critical';

    return Scaffold(
      backgroundColor: isCritical ? const Color(0xFFFEF2F2) : const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: isCritical ? const Color(0xFFDC2626) : const Color(0xFF1D4ED8),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monitoreo Remoto', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text(widget.patientEmail, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: _isConnected ? const Color(0xFFE0F2FE) : const Color(0xFFFEE2E2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: _isConnected ? const Color(0xFF0369A1) : const Color(0xFFB91C1C),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _isConnected ? 'Recibiendo datos del paciente' : 'Esperando datos del paciente...',
                  style: TextStyle(
                    color: _isConnected ? const Color(0xFF0369A1) : const Color(0xFFB91C1C),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))))
          else if (!_isConnected || _reading == null)
            _buildErrorView('No se están recibiendo datos del paciente', 'Sin datos', 'Estado: Sin conexión')
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

  Widget _buildNormalView(Map<String, dynamic> r) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _statusBadge(r['risk_level']),
        const SizedBox(height: 16),
        _bigMetricCard(
          label: 'Frecuencia cardíaca:',
          value: '${r['bpm']}',
          unit: 'BPM',
          color: _bpmColor(r['bpm']),
          icon: Icons.favorite_rounded,
        ),
        const SizedBox(height: 12),
        _smallMetricCard('Saturación (SpO₂)', '${r['spo2']}%', Icons.water_drop_rounded, _spo2Color(r['spo2'])),
      ],
    );
  }

  Widget _buildCriticalView(Map<String, dynamic> r) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _statusBadge(r['risk_level']),
        const SizedBox(height: 16),
        _bigMetricCard(
          label: 'Frecuencia cardíaca:',
          value: '${r['bpm']}',
          unit: 'BPM',
          color: const Color(0xFFDC2626),
          icon: Icons.favorite_rounded,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text('PACIENTE EN RIESGO CRÍTICO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String riskLevel) {
    String text;
    Color color;

    if (riskLevel == 'normal') {
      text = 'Estado: Normal';
      color = const Color(0xFF10B981);
    } else if (riskLevel == 'moderate') {
      text = 'Estado: Bajo';
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

  Color _spo2Color(dynamic spo2) {
    final val = (spo2 is int) ? spo2.toDouble() : spo2 as double;
    if (val < 82) return const Color(0xFFDC2626);
    if (val < 90) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }
}
