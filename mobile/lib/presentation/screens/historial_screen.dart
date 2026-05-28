// lib/presentation/screens/historial_screen.dart
//
// RF13 — Consulta de historial biométrico desde el backend.
// Muestra las últimas 100 lecturas de BPM + SpO₂ con nivel de riesgo.
import 'package:flutter/material.dart';
import '../../infrastructure/api_client/api_client.dart';
import '../../infrastructure/auth/auth_service.dart';
import '../../domain/models/biometric_signal_model.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});
  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  List<BiometricSignalResponse> _readings = [];
  bool _isLoading = true;
  String? _error;
  final ApiClient _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final userId = AuthService().currentUser?.id ?? '';
      if (userId.isEmpty) throw Exception('Sesión no iniciada');
      final list = await _api.getSignalHistory(patientId: userId, limit: 100);
      if (mounted) setState(() { _readings = list; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : _error != null
              ? _buildError()
              : CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  children: [
                                    const Text('Historial Biométrico',
                                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
                                    const Spacer(),
                                    Text('${_readings.length} registros',
                                        style: const TextStyle(color: Colors.white30, fontSize: 12)),
                                  ],
                                ),
                              );
                            }
                            final item = _readings[index - 1];
                            return _buildCard(item);
                          },
                          childCount: _readings.isEmpty ? 1 : _readings.length + 1,
                        ),
                      ),
                    ),
                    if (_readings.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.monitor_heart_rounded, size: 54, color: Colors.white12),
                              SizedBox(height: 16),
                              Text('No hay lecturas aún.\nConecta tu SmartWatch para empezar.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white30, fontSize: 13, height: 1.5)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildCard(BiometricSignalResponse item) {
    final riskLevel = item.riskLevel.name.toLowerCase();
    final Color accentColor = riskLevel == 'critical'
        ? const Color(0xFFEF4444)
        : riskLevel == 'moderate'
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);

    String timeStr = '—';
    if (true) {
      final dt = item.time.toLocal();
      timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}  '
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.15), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 48,
            decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(timeStr, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _pill('SpO₂ ${item.spo2.toStringAsFixed(1)}%', const Color(0xFF60A5FA)),
                    const SizedBox(width: 8),
                    _pill('${item.heartRate} BPM', const Color(0xFFEC4899)),
                    const SizedBox(width: 8),
                    _pill((item.riskLevel.name).toUpperCase(), accentColor),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            riskLevel == 'critical' || riskLevel == 'moderate'
                ? Icons.warning_rounded
                : Icons.check_circle_rounded,
            color: accentColor,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.white24),
          const SizedBox(height: 16),
          Text(_error ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 24),
          TextButton.icon(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
            label: const Text('Reintentar', style: TextStyle(color: Color(0xFF2563EB))),
            onPressed: _fetchHistory,
          ),
        ],
      ),
    );
  }
}
