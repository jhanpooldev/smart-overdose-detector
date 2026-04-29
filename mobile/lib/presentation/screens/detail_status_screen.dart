import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

class DetailStatusScreen extends StatefulWidget {
  const DetailStatusScreen({super.key});

  @override
  State<DetailStatusScreen> createState() => _DetailStatusScreenState();
}

class _DetailStatusScreenState extends State<DetailStatusScreen> {
  final List<FlSpot> _bpmSpots = [];
  final List<FlSpot> _spo2Spots = [];
  double _xValue = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startSimulation();
  }

  void _startSimulation() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _xValue += 0.5;
        // Simulación de BPM oscilando entre 60 y 100
        double bpm = 70 + math.Random().nextDouble() * 20;
        _bpmSpots.add(FlSpot(_xValue, bpm));
        
        // Simulación de SpO2 oscilando entre 94 y 99
        double spo2 = 95 + math.Random().nextDouble() * 4;
        _spo2Spots.add(FlSpot(_xValue, spo2));

        if (_bpmSpots.length > 20) {
          _bpmSpots.removeAt(0);
          _spo2Spots.removeAt(0);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Estado Detallado'),
        backgroundColor: const Color(0xFF1D4ED8),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Frecuencia Cardíaca (BPM)'),
          _buildChart(_bpmSpots, const Color(0xFFDC2626), 50, 120),
          const SizedBox(height: 24),
          _sectionTitle('Saturación de Oxígeno (SpO₂)'),
          _buildChart(_spo2Spots, const Color(0xFF2563EB), 80, 100),
          const SizedBox(height: 24),
          _buildHealthStatus(),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
      ),
    );
  }

  Widget _buildChart(List<FlSpot> spots, Color color, double min, double max) {
    return Container(
      height: 200,
      padding: const EdgeInsets.only(right: 16, top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: LineChart(
        LineChartData(
          minY: min,
          maxY: max,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthStatus() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF10B981)),
                SizedBox(width: 12),
                Text('Sensor: Funcionando correctamente', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            Divider(height: 24),
            Row(
              children: [
                Icon(Icons.battery_full, color: Color(0xFF10B981)),
                SizedBox(width: 12),
                Text('Batería: 85%', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            Divider(height: 24),
            Row(
              children: [
                Icon(Icons.signal_cellular_alt, color: Color(0xFF10B981)),
                SizedBox(width: 12),
                Text('Señal: Excelente', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
