// lib/presentation/screens/device_screen.dart
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
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_rounded, size: 20, color: Colors.white),
            SizedBox(width: 8),
            Text('Estado del Dispositivo', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF131929),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                _statusRow(
                  icon: Icons.watch_rounded,
                  label: 'Wearable',
                  value: _connected ? 'Conectado' : 'Desconectado',
                  valueColor: _connected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  checkIcon: _connected,
                ),
                const Divider(color: Colors.white12, height: 1),
                _statusRow(
                  icon: Icons.bluetooth_rounded,
                  label: 'Bluetooth',
                  value: _bluetoothActive ? 'Activo' : 'Inactivo',
                  valueColor: _bluetoothActive ? const Color(0xFF2563EB) : Colors.white38,
                  checkIcon: _bluetoothActive,
                ),
                const Divider(color: Colors.white12, height: 1),
                _batteryRow(),
                const Divider(color: Colors.white12, height: 1),
                _statusRow(
                  icon: Icons.sync_rounded,
                  label: 'Última sincronización',
                  value: _syncLabel(),
                  valueColor: Colors.white70,
                  checkIcon: null,
                ),
              ],
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
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Reconectar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() { _connected = false; _bluetoothActive = false; });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Conexión detenida'), backgroundColor: Color(0xFFEF4444)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Parar Conexión', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          const Text('Contactos de Emergencia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF131929),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                _contactTile('Juan Pérez', '555-123-4567'),
                const Divider(color: Colors.white12, height: 1),
                _contactTile('Ana López', '555-997-6543'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF2563EB), size: 18),
            label: const Text('Agregar Contacto', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 14)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF2563EB)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow({required IconData icon, required String label, required String value, required Color valueColor, required bool? checkIcon}) {
    return ListTile(
      leading: Icon(icon, color: valueColor, size: 20),
      title: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (checkIcon == true) const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
          if (checkIcon == false) const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 16),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _batteryRow() {
    final color = _battery > 50 ? const Color(0xFF10B981) : _battery > 20 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
    return ListTile(
      leading: Icon(Icons.battery_charging_full_rounded, color: color, size: 20),
      title: const Text('Batería', style: TextStyle(color: Colors.white70, fontSize: 14)),
      trailing: Text('$_battery%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _contactTile(String name, String number) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF2563EB).withOpacity(0.12),
        child: const Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 18),
      ),
      title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
      subtitle: Text(number, style: const TextStyle(fontSize: 12, color: Colors.white54)),
      trailing: IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
        onPressed: () {},
      ),
    );
  }
}
