// lib/presentation/screens/alerta_screen.dart
// Pantalla 2 (⚠️) — Detalle de alerta + historial de eventos de riesgo
import 'package:flutter/material.dart';

class AlertaScreen extends StatelessWidget {
  const AlertaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Historial simulado de eventos
    final history = [
      {'time': '23:05', 'bpm': 42, 'spo2': 76.5, 'level': 'CRITICAL'},
      {'time': '22:47', 'bpm': 58, 'spo2': 87.2, 'level': 'MODERATE'},
      {'time': '21:30', 'bpm': 72, 'spo2': 97.0, 'level': 'NORMAL'},
      {'time': '20:10', 'bpm': 65, 'spo2': 95.5, 'level': 'NORMAL'},
      {'time': '19:02', 'bpm': 48, 'spo2': 80.1, 'level': 'CRITICAL'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Historial de Alertas'),
        backgroundColor: const Color(0xFF1D4ED8),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Resumen hoy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F2937))),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _summaryItem('2', 'Críticos', const Color(0xFFDC2626)),
                      _summaryItem('1', 'Moderados', const Color(0xFFF59E0B)),
                      _summaryItem('2', 'Normales', const Color(0xFF10B981)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Eventos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4B5563))),
          const SizedBox(height: 8),
          ...history.map((e) => _eventCard(e)),
        ],
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
        subtitle: Text(e['time'] as String, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
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
