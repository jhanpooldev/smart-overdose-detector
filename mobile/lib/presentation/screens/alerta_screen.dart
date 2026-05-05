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
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Historial de Alertas'),
        backgroundColor: const Color(0xFF1D4ED8),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _fetchHistory,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Resumen reciente',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F2937))),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _summaryItem(criticalCount.toString(), 'Críticos', const Color(0xFFDC2626)),
                                  _summaryItem(moderateCount.toString(), 'Moderados', const Color(0xFFF59E0B)),
                                  _summaryItem(normalCount.toString(), 'Normales', const Color(0xFF10B981)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Eventos Recientes',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4B5563))),
                      const SizedBox(height: 8),
                      if (_history.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('No hay eventos registrados recientemente'),
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
        Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
      ],
    );
  }

  Widget _eventCard(Map<String, dynamic> e) {
    final level = e['level'] as String;
    final Color color = level == 'CRITICAL'
        ? const Color(0xFFDC2626)
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

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 4,
          height: 48,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        title: Text(
          '${e['bpm']} BPM — SpO₂ ${e['spo2']}%',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1F2937)),
        ),
        subtitle: Text(timeStr, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 4),
            Text(level, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
