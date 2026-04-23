import 'package:flutter/material.dart';
import 'domain/entities/biometric_reading.dart';
import 'infrastructure/sensors/simulated_sensor/simulated_sensor_adapter.dart';
import 'presentation/widgets/simulation_badge.dart';

void main() {
  runApp(const SmartOverdoseDetectorApp());
}

class SmartOverdoseDetectorApp extends StatelessWidget {
  const SmartOverdoseDetectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Overdose Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SimulatedSensorAdapter _sensorAdapter = SimulatedSensorAdapter();

  @override
  void dispose() {
    _sensorAdapter.stopSimulation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Biométrico'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<ScenarioType>(
              value: _sensorAdapter.currentScenario,
              underline: const SizedBox(),
              dropdownColor: Colors.grey.shade900,
              items: const [
                DropdownMenuItem(
                  value: ScenarioType.normal,
                  child: Text('Normal'),
                ),
                DropdownMenuItem(
                  value: ScenarioType.moderate,
                  child: Text('Moderado'),
                ),
                DropdownMenuItem(
                  value: ScenarioType.critical,
                  child: Text('Crítico'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _sensorAdapter.setScenario(value);
                  });
                }
              },
            ),
          )
        ],
      ),

      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),

                Text(
                  'Datos en Tiempo Real',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 24),

                Expanded(
                  child: StreamBuilder<BiometricReading>(
                    stream: _sensorAdapter.biometricStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}'),
                        );
                      }

                      final reading = snapshot.data;

                      if (reading == null) {
                        return const Center(
                          child: Text('No hay datos disponibles'),
                        );
                      }

                      bool isCritical =
                          reading.spo2 < 82 || reading.bpm < 50;

                      return Card(
                        elevation: 12,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        color: isCritical
                            ? Colors.red.shade900.withOpacity(0.25)
                            : Colors.grey.shade900,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildMetricTile(
                                label: 'SpO2',
                                value: '${reading.spo2}%',
                                icon: Icons.water_drop,
                                color: reading.spo2 < 90
                                    ? Colors.redAccent
                                    : Colors.cyanAccent,
                              ),
                              const SizedBox(height: 16),

                              _buildMetricTile(
                                label: 'Frecuencia Cardíaca',
                                value: '${reading.bpm} BPM',
                                icon: Icons.favorite,
                                color: (reading.bpm < 60 ||
                                        reading.bpm > 100)
                                    ? Colors.redAccent
                                    : Colors.pinkAccent,
                              ),
                              const SizedBox(height: 16),

                              _buildMetricTile(
                                label: 'Actividad',
                                value: reading.activity == 1
                                    ? 'Activo'
                                    : 'Reposo',
                                icon: Icons.directions_run,
                                color: Colors.greenAccent,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(child: SimulationBadge()),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}