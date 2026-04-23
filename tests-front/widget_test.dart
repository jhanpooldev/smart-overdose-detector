// tests-front/widget_test.dart
// Pruebas de widget Flutter para el Smart Overdose Detector — PMV1.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mobile/lib/main.dart';
import '../mobile/lib/infrastructure/sensors/simulated_sensor/simulated_sensor_adapter.dart';
import '../mobile/lib/presentation/widgets/simulation_badge.dart';

void main() {
  group('SimulationBadge Widget', () {
    testWidgets('debe mostrar texto MODO SIMULACIÓN', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SimulationBadge())),
      );
      expect(find.text('MODO SIMULACIÓN'), findsOneWidget);
    });

    testWidgets('debe mostrar ícono de ciencia', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SimulationBadge())),
      );
      expect(find.byIcon(Icons.science), findsOneWidget);
    });
  });

  group('DashboardScreen', () {
    testWidgets('badge MODO SIMULACIÓN está presente en el árbol de widgets',
        (tester) async {
      await tester.pumpWidget(const SmartOverdoseDetectorApp());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SimulationBadge), findsOneWidget);
    });

    testWidgets('tiene selector de escenario (DropdownButton)', (tester) async {
      await tester.pumpWidget(const SmartOverdoseDetectorApp());
      await tester.pump();
      expect(find.byType(DropdownButton<ScenarioType>), findsOneWidget);
    });

    testWidgets('muestra indicadores SpO2 y Frecuencia Cardíaca', (tester) async {
      await tester.pumpWidget(const SmartOverdoseDetectorApp());
      // Esperar primer tick del simulador
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('SpO2'), findsWidgets);
      expect(find.textContaining('BPM'), findsWidgets);
    });
  });

  group('SimulatedSensorAdapter', () {
    test('emite lecturas continuas en el stream', () async {
      final adapter = SimulatedSensorAdapter();
      final reading = await adapter.biometricStream.first;
      expect(reading.spo2, greaterThanOrEqualTo(70.0));
      expect(reading.bpm, greaterThanOrEqualTo(30));
      adapter.stopSimulation();
    });

    test('escenario crítico → SpO2 < 82 y BPM < 50', () async {
      final adapter = SimulatedSensorAdapter();
      adapter.setScenario(ScenarioType.critical);
      final reading = await adapter.biometricStream.first;
      expect(reading.spo2, lessThan(82.0));
      expect(reading.bpm, lessThan(50));
      adapter.stopSimulation();
    });

    test('cambiar escenario refleja en las lecturas siguientes', () async {
      final adapter = SimulatedSensorAdapter();
      adapter.setScenario(ScenarioType.normal);
      expect(adapter.currentScenario, ScenarioType.normal);
      adapter.setScenario(ScenarioType.critical);
      expect(adapter.currentScenario, ScenarioType.critical);
      adapter.stopSimulation();
    });
  });
}
