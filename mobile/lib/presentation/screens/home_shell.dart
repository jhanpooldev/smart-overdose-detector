// lib/presentation/screens/home_shell.dart
import 'package:flutter/material.dart';
import '../../infrastructure/auth/auth_service.dart';
import '../../domain/entities/user.dart';
import 'supervisor_dashboard_screen.dart';
import 'monitor_screen_v2.dart';
import 'alerta_screen.dart';
import 'umbrales_screen.dart';
import 'contacts_screen.dart';
import 'device_screen.dart';
import 'login_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  List<Widget> get _screens {
    final isSup = AuthService().currentUser?.role == Role.supervisor;
    if (isSup) {
      // Supervisor: Pacientes | Alertas | Ajustes
      return [
        const SupervisorDashboardScreen(),
        const AlertaScreen(),
        const UmbralesScreen(),
      ];
    }
    // Paciente: Monitor | Alertas | Contactos | Dispositivo | Ajustes
    return [
      const MonitorScreenV2(),
      const AlertaScreen(),
      const ContactsScreen(),
      const DeviceScreen(),
      const UmbralesScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final isSup = user?.role == Role.supervisor;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF131929),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Monitor (paciente) / Pacientes (supervisor)
              _navItem(0,
                  isSup ? Icons.supervisor_account_rounded : Icons.favorite_rounded,
                  isSup ? 'Pacientes' : 'Monitor'),
              // Alertas
              _navItem(1, Icons.warning_rounded, 'Alertas'),
              // Contactos (solo paciente)
              if (!isSup) _navItem(2, Icons.people_rounded, 'Contactos'),
              // Dispositivo (solo paciente) — RF08
              if (!isSup) _navItem(3, Icons.watch_rounded, 'Dispositivo'),
              // Ajustes
              _navItem(isSup ? 2 : 4, Icons.settings_rounded, 'Ajustes'),
              // Logout
              _logoutButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF2563EB) : Colors.white38, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF2563EB) : Colors.white38,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoutButton() {
    return InkWell(
      onTap: () {
        AuthService().logout();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 22),
            const SizedBox(height: 4),
            Text('Salir', style: TextStyle(color: Colors.red.shade400, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
