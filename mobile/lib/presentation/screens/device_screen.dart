// lib/presentation/screens/device_screen.dart
// Pantalla 4 (📶) — Estado del Dispositivo (Wearable + conexión)
import 'dart:async';
import 'package:flutter/material.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  bool _connected = true;
  bool _bluetoothActive = true;
  int _battery = 82;
  int _secondsSinceSync = 0;
  late Timer _syncTimer;

  @override
  void initState() {
    super.initState();
    // Simula tiempo desde última sincronización
    _syncTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _secondsSinceSync++);
    });
  }

  @override
  void dispose() {
    _syncTimer.cancel();
    super.dispose();
  }

  String _syncLabel() {
    if (_secondsSinceSync < 60) return 'Hace $_secondsSinceSync segundos';
    final mins = _secondsSinceSync ~/ 60;
    return 'Hace $mins minuto${mins > 1 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D4ED8),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.wifi_rounded, size: 18, color: Colors.white),
            SizedBox(width: 8),
            Text('Estado del Dispositivo', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _statusRow(
                    icon: Icons.watch_rounded,
                    label: 'Wearable',
                    value: _connected ? 'Conectado' : 'Desconectado',
                    valueColor: _connected ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                    checkIcon: _connected,
                  ),
                  const Divider(height: 1),
                  _statusRow(
                    icon: Icons.bluetooth_rounded,
                    label: 'Bluetooth',
                    value: _bluetoothActive ? 'Activo' : 'Inactivo',
                    valueColor: _bluetoothActive ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF),
                    checkIcon: _bluetoothActive,
                  ),
                  const Divider(height: 1),
                  _batteryRow(),
                  const Divider(height: 1),
                  _statusRow(
                    icon: Icons.sync_rounded,
                    label: 'Última sincronización:',
                    value: _syncLabel(),
                    valueColor: const Color(0xFF6B7280),
                    checkIcon: null,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() { _connected = true; _secondsSinceSync = 0; });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reconectando...'), backgroundColor: Color(0xFF2563EB)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Reconectar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() { _connected = false; _bluetoothActive = false; });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Conexión detenida'), backgroundColor: Color(0xFFDC2626)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Parar Conexión', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Contactos de emergencia (misma pantalla que el mockup de contacto)
          const Text('Contactos de Emergencia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F2937))),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _contactTile('Juan Pérez', '555-123-4567'),
                const Divider(height: 1),
                _contactTile('Ana López', '555-997-6543'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF2563EB)),
            label: const Text('Agregar Contacto', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF2563EB)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow({required IconData icon, required String label, required String value, required Color valueColor, required bool? checkIcon}) {
    return ListTile(
      leading: Icon(icon, color: valueColor, size: 22),
      title: Text(label, style: const TextStyle(color: Color(0xFF374151), fontSize: 14)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (checkIcon == true) const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
          if (checkIcon == false) const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 16),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _batteryRow() {
    final color = _battery > 50 ? const Color(0xFF10B981) : _battery > 20 ? const Color(0xFFF59E0B) : const Color(0xFFDC2626);
    return ListTile(
      leading: Icon(Icons.battery_charging_full_rounded, color: color, size: 22),
      title: const Text('Batería', style: TextStyle(color: Color(0xFF374151), fontSize: 14)),
      trailing: Text('$_battery%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _contactTile(String name, String number) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFE0E7FF),
        child: Icon(Icons.person_outline, color: Color(0xFF2563EB), size: 18),
      ),
      title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1F2937))),
      subtitle: Text(number, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
      trailing: Icon(Icons.close_rounded, color: Colors.red.shade300, size: 18),
    );
  }
}
