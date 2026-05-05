// lib/presentation/screens/home_shell.dart
// Shell con navegación inferior de 4 pantallas
import 'package:flutter/material.dart';
import '../../infrastructure/auth/auth_service.dart';
import '../../domain/entities/user.dart';
import 'supervisor_dashboard_screen.dart';
import 'monitor_screen.dart';
import 'alerta_screen.dart';
import 'umbrales_screen.dart';
import 'contacts_screen.dart';
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
      return [
        const SupervisorDashboardScreen(),
        const AlertaScreen(),
        const UmbralesScreen(),
      ];
    }
    return [
      const MonitorScreen(),
      const AlertaScreen(),
      const ContactsScreen(),
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
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, isSup ? Icons.supervisor_account_rounded : Icons.favorite_rounded, isSup ? 'Pacientes' : 'Monitor'),
              _navItem(1, Icons.warning_rounded, 'Alertas'),
              if (!isSup) _navItem(2, Icons.people_rounded, 'Contactos'),
              _navItem(isSup ? 2 : 3, Icons.settings_rounded, 'Ajustes'),
              // Logout
              InkWell(
                onTap: () {
                  AuthService().logout();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 24),
                      const SizedBox(height: 2),
                      Text('Salir', style: TextStyle(color: Colors.red.shade400, fontSize: 10)),
                    ],
                  ),
                ),
              ),
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF), size: 24),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF),
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            )),
          ],
        ),
      ),
    );
  }

  Color _roleColor(Role? role) {
    switch (role) {
      case Role.supervisor: return const Color(0xFF7C3AED);
      case Role.paciente: return const Color(0xFF10B981);
      default: return const Color(0xFF2563EB);
    }
  }
}
