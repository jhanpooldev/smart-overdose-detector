// lib/presentation/screens/historial_screen.dart

import 'package:flutter/material.dart';

class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mockHistory = List.generate(15, (i) {
      final spo2 = 85.0 + (i * 0.8);
      final bpm = 55 + i * 2;
      final isRisk = spo2 < 90 || bpm < 60;
      return {
        'spo2': spo2.toStringAsFixed(1),
        'bpm': bpm.toString(),
        'activity': i.isEven ? 1 : 0,
        'time': '${12 + i ~/ 4}:${(i * 4).toString().padLeft(2, '0')}:00',
        'isRisk': isRisk,
      };
    }).reversed.toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = mockHistory[index];
                  final isRisk = item['isRisk'] as bool;

                  final accentColor = isRisk
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF10B981);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF131929),
                          const Color(0xFF0F1424),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accentColor.withOpacity(0.25),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 50,
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['time'] as String,
                                  style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _pill('SpO₂ ${item['spo2']}%', const Color(0xFF60A5FA)),
                                    const SizedBox(width: 8),
                                    _pill('${item['bpm']} BPM', const Color(0xFFEC4899)),
                                    const SizedBox(width: 8),
                                    _pill(
                                      item['activity'] == 1 ? 'Activo' : 'Reposo',
                                      const Color(0xFF10B981),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          Icon(
                            isRisk
                                ? Icons.warning_rounded
                                : Icons.check_circle_rounded,
                            color: accentColor,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: mockHistory.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}