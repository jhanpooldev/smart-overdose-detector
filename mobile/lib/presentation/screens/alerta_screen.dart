// lib/presentation/screens/alerta_screen.dart
import 'package:flutter/material.dart';
import '../../infrastructure/auth/auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AlertaScreen extends StatefulWidget {
  const AlertaScreen({super.key});

  @override
  State<AlertaScreen> createState() => _AlertaScreenState();
}

class _AlertaScreenState extends State<AlertaScreen> {
  List<dynamic> _history = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = AuthService();
      final user = auth.currentUser;
      final response = await http.get(
        Uri.parse('${auth.baseUrl.replaceAll('/auth', '')}/alerts?patient_id=${user?.id}'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _history = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Error al cargar el historial';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de conexión';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    int criticalCount = _history.where((e) => e['level'] == 'CRITICAL').length;
    int moderateCount = _history.where((e) => e['level'] == 'MODERATE').length;
    int normalCount = _history.where((e) => e['level'] == 'NORMAL').length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.history_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text('Historial de Alertas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : RefreshIndicator(
                  color: const Color(0xFF2563EB),
                  backgroundColor: const Color(0xFF131929),
                  onRefresh: _fetchHistory,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    children: [
                      // Summary Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131929),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Resumen Reciente',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _summaryItem(criticalCount.toString(), 'Críticos', const Color(0xFFEF4444)),
                                Container(width: 1, height: 36, color: Colors.white12),
                                _summaryItem(moderateCount.toString(), 'Moderados', const Color(0xFFF59E0B)),
                                Container(width: 1, height: 36, color: Colors.white12),
                                _summaryItem(normalCount.toString(), 'Normales', const Color(0xFF10B981)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Eventos Recientes',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white70)),
                      const SizedBox(height: 12),
                      if (_history.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Text('No hay eventos registrados recientemente', style: TextStyle(color: Colors.white30, fontSize: 13)),
                          ),
                        ),
                      ..._history.map((e) => _eventCard(e)),
                    ],
                  ),
                ),
    );
  }

  Widget _summaryItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white30, fontSize: 11)),
      ],
    );
  }

  Widget _eventCard(Map<String, dynamic> e) {
    final level = e['level'] as String;
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

    final DateTime dt = DateTime.parse(e['timestamp']);
    final String timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${e['bpm']} BPM — SpO₂ ${e['spo2']}%',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(timeStr, style: const TextStyle(color: Colors.white30, fontSize: 11)),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(level, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
