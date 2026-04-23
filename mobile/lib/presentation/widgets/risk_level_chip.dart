// lib/presentation/widgets/risk_level_chip.dart
// Banner de nivel de riesgo con colores dinámicos y animación de pulso.

import 'package:flutter/material.dart';
import '../../domain/entities/risk_prediction.dart';

class RiskLevelChip extends StatelessWidget {
  final RiskLevel level;

  const RiskLevelChip({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final (color, bgColor, label, icon) = switch (level) {
      RiskLevel.normal => (
          const Color(0xFF10B981),
          const Color(0xFF10B981),
          'ESTADO NORMAL',
          Icons.check_circle_rounded,
        ),
      RiskLevel.moderate => (
          const Color(0xFFF59E0B),
          const Color(0xFFF59E0B),
          'RIESGO MODERADO — Monitoreo Activo',
          Icons.warning_rounded,
        ),
      RiskLevel.critical => (
          const Color(0xFFEF4444),
          const Color(0xFFEF4444),
          '🚨 RIESGO CRÍTICO — Llamar al 911',
          Icons.emergency_rounded,
        ),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
