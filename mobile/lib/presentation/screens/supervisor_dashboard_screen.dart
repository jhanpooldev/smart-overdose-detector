import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../infrastructure/auth/auth_service.dart';
import 'remote_monitor_screen.dart';

class SupervisorDashboardScreen extends StatefulWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  State<SupervisorDashboardScreen> createState() => _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState extends State<SupervisorDashboardScreen> {
  List<dynamic> _patients = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = AuthService();
      final response = await http.get(
        Uri.parse('${auth.baseUrl}/patients'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _patients = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Error al cargar pacientes');
      }
    } catch (e) {
      setState(() {
        _error = 'No se pudieron cargar los pacientes asignados.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D4ED8),
        title: const Row(
          children: [
            Icon(Icons.dashboard_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Panel de Supervisor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchPatients,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _patients.isEmpty
                  ? const Center(child: Text('No tienes pacientes asignados.', style: TextStyle(color: Colors.black54)))
                  : RefreshIndicator(
                      onRefresh: _fetchPatients,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _patients.length,
                        itemBuilder: (context, index) {
                          final p = _patients[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE0F2FE),
                                child: Icon(Icons.person, color: Color(0xFF0369A1)),
                              ),
                              title: const Text('Paciente', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              subtitle: Text(p['email'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16)),
                              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RemoteMonitorScreen(patientId: p['id'], patientEmail: p['email']),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
