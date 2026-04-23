enum RiskLevel {
  normal,
  moderate,
  critical,
}

class RiskPrediction {
  final RiskLevel level;
  final double probability;

  RiskPrediction({
    required this.level,
    required this.probability,
  });
}
