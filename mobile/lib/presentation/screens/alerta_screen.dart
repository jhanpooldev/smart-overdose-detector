// lib/presentation/screens/alerta_screen.dart
//
// RF13 — Historial de registros de salud (alertas biométricas).
// RF14 — Exportación del historial a CSV.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../infrastructure/api_client/api_client.dart';
import '../../infrastructure/auth/auth_service.dart';
import '../../domain/models/biometric_signal_model.dart';

class AlertaScreen extends StatefulWidget {
  const AlertaScreen({super.key});
  @override
  State<AlertaScreen> createState() => _AlertaScreenState();
}

class _AlertaScreenState extends State<AlertaScreen> {
  // ── Datos de alertas ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> _alerts = [];
  // ── Historial biométrico (RF13) ────────────────────────────────────────────
  List<BiometricSignalResponse> _history = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;

  final ApiClient _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() { _isLoading = true; _error = null; });
    await Future.wait([_fetchAlerts(), _fetchHistory()]);
    if (mounted) setState(() => _isLoading = false);
  }

  // ── RF13: Cargar alertas de riesgo del backend ─────────────────────────────
  Future<void> _fetchAlerts() async {
    try {
      final userId = AuthService().currentUser?.id ?? '';
      final list = await _api.getAlerts(patientId: userId, limit: 50);
      if (mounted) setState(() => _alerts = list);
    } catch (_) {
      // No bloquea la UI — el historial biométrico igual se carga
    }
  }

  // ── RF13: Historial biométrico completo ────────────────────────────────────
  Future<void> _fetchHistory() async {
    try {
      final userId = AuthService().currentUser?.id ?? '';
      if (userId.isEmpty) return;
      final list = await _api.getSignalHistory(patientId: userId, limit: 100);
      if (mounted) setState(() => _history = list);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo cargar el historial: ${e.toString()}');
    }
  }

  // ── RF14: Exportar historial a CSV ─────────────────────────────────────────
  Future<void> _exportCsv() async {
    if (_history.isEmpty && _alerts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para exportar'), backgroundColor: Color(0xFFF59E0B)),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final buffer = StringBuffer();
      buffer.writeln('Tipo,Timestamp,BPM,SpO2,Nivel_Riesgo');

      // Historial biométrico
      for (final s in _history) {
        final ts = s.time.toLocal().toIso8601String();
        buffer.writeln('LECTURA,$ts,${s.heartRate},${s.spo2},${s.riskLevel.name}');
      }

      // Alertas de riesgo
      for (final a in _alerts) {
        final ts = a['timestamp'] ?? '';
        final bpm = a['bpm'] ?? '';
        final spo2 = a['spo2'] ?? '';
        final level = a['level'] ?? '';
        buffer.writeln('ALERTA,$ts,$bpm,$spo2,$level');
      }

      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final filename = 'historial_${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}.csv';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles([XFile(file.path)], subject: 'Historial de Salud — Smart Overdose Detector');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── Stats ──────────────────────────────────────────────────────────────────
  int get _criticalCount => _alerts.where((e) => (e['level'] ?? '').toString().toUpperCase() == 'CRITICAL').length;
  int get _moderateCount => _alerts.where((e) => (e['level'] ?? '').toString().toUpperCase() == 'MODERATE').length;
  int get _normalCount   => _alerts.where((e) => (e['level'] ?? '').toString().toUpperCase() == 'NORMAL').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.history_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text('Historial de Salud',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          // RF14 — Exportar CSV
          IconButton(
            icon: _isExporting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Exportar CSV',
            onPressed: _isExporting ? null : _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchAll,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : _error != null && _history.isEmpty && _alerts.isEmpty
              ? _buildError()
              : RefreshIndicator(
                  color: const Color(0xFF2563EB),
                  backgroundColor: const Color(0xFF131929),
                  onRefresh: _fetchAll,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    children: [
                      // ── Resumen de alertas ────────────────────────────────
                      _buildSummaryCard(),
                      const SizedBox(height: 24),

                      // ── Historial biométrico RF13 ─────────────────────────
                      if (_history.isNotEmpty) ...[
                        Row(
                          children: [
                            const Text('Lecturas Biométricas',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white70)),
                            const Spacer(),
                            Text('${_history.length} registros',
                                style: const TextStyle(color: Colors.white30, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._history.take(30).map(_buildReadingCard),
                      ],

                      // ── Alertas de riesgo ─────────────────────────────────
                      if (_alerts.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text('Alertas Registradas',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white70)),
                        const SizedBox(height: 12),
                        ..._alerts.map(_buildAlertCard),
                      ],

                      if (_history.isEmpty && _alerts.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: Column(
                              children: [
                                Icon(Icons.history_toggle_off_rounded, size: 54, color: Colors.white12),
                                SizedBox(height: 16),
                                Text('No hay registros aún.\nConecta tu SmartWatch para comenzar.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white30, fontSize: 13, height: 1.5)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  // ── Resumen ────────────────────────────────────────────────────────────────
  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Text('Resumen de Alertas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
              const Spacer(),
              // RF14 — botón exportar inline
              TextButton.icon(
                onPressed: _isExporting ? null : _exportCsv,
                icon: const Icon(Icons.download_rounded, size: 14, color: Color(0xFF60A5FA)),
                label: const Text('Exportar CSV', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 11)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem(_criticalCount.toString(), 'Críticos', const Color(0xFFEF4444)),
              Container(width: 1, height: 36, color: Colors.white12),
              _summaryItem(_moderateCount.toString(), 'Moderados', const Color(0xFFF59E0B)),
              Container(width: 1, height: 36, color: Colors.white12),
              _summaryItem(_normalCount.toString(), 'Normales', const Color(0xFF10B981)),
              Container(width: 1, height: 36, color: Colors.white12),
              _summaryItem(_history.length.toString(), 'Lecturas', const Color(0xFF60A5FA)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white30, fontSize: 10)),
      ],
    );
  }

  // ── Tarjeta de lectura biométrica (RF13) ───────────────────────────────────
  Widget _buildReadingCard(BiometricSignalResponse r) {
    final riskLevel = r.riskLevel.name.toLowerCase();
    final Color color = riskLevel == 'critical'
        ? const Color(0xFFEF4444)
        : riskLevel == 'moderate'
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);

    final timeStr = _formatDateTime(r.time.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 4, height: 44,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.favorite_rounded, color: Color(0xFFEF4444), size: 14),
                    const SizedBox(width: 4),
                    Text('${r.heartRate} BPM', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 16),
                    const Icon(Icons.water_drop_rounded, color: Color(0xFF2563EB), size: 14),
                    const SizedBox(width: 4),
                    Text('${r.spo2}% SpO₂',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(timeStr, style: const TextStyle(color: Colors.white30, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              r.riskLevel.name.toUpperCase(),
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tarjeta de alerta ──────────────────────────────────────────────────────
  Widget _buildAlertCard(Map<String, dynamic> e) {
    final level = (e['level'] ?? 'NORMAL').toString().toUpperCase();
    final Color color = level == 'CRITICAL'
        ? const Color(0xFFEF4444)
        : level == 'MODERATE'
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);
    final IconData icon = level == 'CRITICAL'
        ? Icons.emergency_rounded
        : level == 'MODERATE'
            ? Icons.warning_rounded
            : Icons.check_circle_rounded;

    String timeStr = '—';
    try {
      final dt = DateTime.parse(e['timestamp'].toString()).toLocal();
      timeStr = _formatDateTime(dt);
    } catch (_) {}

    final bpm  = e['bpm']  ?? e['heart_rate'] ?? '—';
    final spo2 = e['spo2'] ?? '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 4, height: 44,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$bpm BPM — SpO₂ $spo2%',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                const SizedBox(height: 4),
                Text(timeStr, style: const TextStyle(color: Colors.white30, fontSize: 11)),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 5),
              Text(level, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 54, color: Colors.white24),
            const SizedBox(height: 16),
            Text(_error ?? 'Error desconocido',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 24),
            TextButton.icon(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
              label: const Text('Reintentar', style: TextStyle(color: Color(0xFF2563EB))),
              onPressed: _fetchAll,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final d = '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    final t = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    return '$d $t';
  }
}
