// lib/presentation/screens/configuracion_screen.dart
// Pantalla de configuración — umbrales clínicos y datos del paciente.

import 'package:flutter/material.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  double _spo2Threshold = 85.0;
  double _bpmMinThreshold = 50.0;
  bool _notifyOnModerate = false;
  bool _highContrastMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('👤 Paciente'),
          _infoTile('Nombre', 'Carlos Mendoza'),
          _infoTile('DNI', '12345678'),
          _infoTile('Edad', '34 años'),
          _infoTile('Teléfono', '+51 987 654 321'),
          const SizedBox(height: 24),

          _sectionTitle('⚙️ Umbrales Clínicos'),
          _sliderTile(
            'SpO₂ mínimo crítico',
            '${_spo2Threshold.toStringAsFixed(1)}%',
            _spo2Threshold,
            70.0,
            95.0,
            (v) => setState(() => _spo2Threshold = v),
            const Color(0xFF60A5FA),
          ),
          _sliderTile(
            'FC mínima crítica',
            '${_bpmMinThreshold.toStringAsFixed(0)} BPM',
            _bpmMinThreshold,
            30.0,
            70.0,
            (v) => setState(() => _bpmMinThreshold = v),
            const Color(0xFFEC4899),
          ),
          const SizedBox(height: 16),

          _sectionTitle('🔔 Alertas'),
          _switchTile(
            'Notificar en riesgo moderado',
            'Envía alerta también en estado moderado',
            _notifyOnModerate,
            (v) => setState(() => _notifyOnModerate = v),
          ),
          _switchTile(
            'Modo alto contraste',
            'Para situaciones de estrés (RNF-10)',
            _highContrastMode,
            (v) => setState(() => _highContrastMode = v),
          ),
          const SizedBox(height: 24),

          _sectionTitle('📞 Contacto de Emergencia'),
          _infoTile('Nombre', 'María Mendoza'),
          _infoTile('Relación', 'Familiar (Principal)'),
          _infoTile('Teléfono', '+51 912 345 678'),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PMV1 — Modo Simulación Activo. Los datos son generados artificialmente.',
                    style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF60A5FA),
          fontWeight: FontWeight.bold,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _sliderTile(
    String label,
    String valueText,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
              Text(valueText,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: color,
            inactiveColor: color.withOpacity(0.2),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _switchTile(
    String label,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                Text(subtitle,
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF60A5FA),
          ),
        ],
      ),
    );
  }
}
