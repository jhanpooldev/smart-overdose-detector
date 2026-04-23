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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue.shade900,
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
        title: const Text('Dashboard Biom\u00E9trico'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButton<ScenarioType>(
              value: _sensorAdapter.currentScenario,
              underline: const SizedBox(),
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
              onChanged: (ScenarioType? newValue) {
                if (newValue != null) {
                  setState(() {
                    _sensorAdapter.setScenario(newValue);
                  });
                }
              },
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          // Background content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60), // Space for simulation badge
                Text(
                  'Datos en Tiempo Real',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                Expanded(
                  child: StreamBuilder<BiometricReading>(
                    stream: _sensorAdapter.biometricStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      
                      final reading = snapshot.data;
                      if (reading == null) {
                        return const Center(child: Text('No hay datos disponibles.'));
                      }

                      bool isCritical = reading.spo2 < 82 || reading.bpm < 50;

                      return Card(
                        color: isCritical ? Colors.red.shade900.withOpacity(0.4) : null,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildMetricRow('SpO2', '${reading.spo2}%', Icons.water_drop, 
                                  reading.spo2 < 90 ? Colors.red : Colors.lightBlue),
                              const Divider(height: 48),
                              _buildMetricRow('Frecuencia Cardíaca', '${reading.bpm} BPM', Icons.favorite,
                                  reading.bpm < 60 || reading.bpm > 100 ? Colors.red : Colors.pink),
                              const Divider(height: 48),
                              _buildMetricRow('Actividad', reading.activity == 1 ? 'Activo' : 'Reposo', 
                                  Icons.directions_run, Colors.green),
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
          
          // Simulation Badge overlay
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

  Widget _buildMetricRow(String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 18)),
          ],
        ),
        Text(
          value, 
          style: TextStyle(
            fontSize: 24, 
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
