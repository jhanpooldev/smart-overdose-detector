// lib/presentation/screens/supervisor_dashboard_screen.dart
// Panel del Supervisor: lista de pacientes vinculados con estado de riesgo
import 'dart:async';
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
  // Mapa de patient.id → última lectura {bpm, spo2, risk_level}
  final Map<String, Map<String, dynamic>> _latestReadings = {};
  bool _isLoading = true;
  String? _error;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPatients() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final auth = AuthService();
      final response = await http.get(
        Uri.parse('${auth.baseUrl}/patients'),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );
      if (response.statusCode == 200) {
        final patients = jsonDecode(response.body) as List;
        setState(() { _patients = patients; _isLoading = false; });
        // Iniciar polling de signos vitales de todos los pacientes
        _startPolling();
      } else {
        throw Exception('Error al cargar pacientes');
      }
    } catch (e) {
      setState(() { _error = 'No se pudieron cargar los pacientes asignados.'; _isLoading = false; });
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollReadings();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollReadings());
  }

  Future<void> _pollReadings() async {
    if (!mounted) return;
    final auth = AuthService();
    final baseApi = auth.baseUrl.replaceAll('/auth', '');
    for (final p in _patients) {
      try {
        final r = await http.get(
          Uri.parse('$baseApi/readings/${p['id']}/latest'),
          headers: {'Authorization': 'Bearer ${auth.token}'},
        );
        if (r.statusCode == 200 && mounted) {
          setState(() { _latestReadings[p['id']] = jsonDecode(r.body); });
        }
      } catch (_) {}
    }
  }

  Color _riskColor(String? risk) {
    switch (risk) {
      case 'critical': return const Color(0xFFDC2626);
      case 'moderate': return const Color(0xFFF59E0B);
      default: return const Color(0xFF10B981);
    }
  }

  String _riskLabel(String? risk) {
    switch (risk) {
      case 'critical': return '🔴 Crítico';
      case 'moderate': return '🟡 Moderado';
      default: return '🟢 Normal';
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
            Icon(Icons.supervisor_account, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text('Mis Pacientes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchPatients,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : _error != null
              ? _buildError()
              : _patients.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _fetchPatients,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _patients.length,
                        itemBuilder: (context, i) => _buildPatientCard(_patients[i]),
                      ),
                    ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> p) {
    final reading = _latestReadings[p['id']];
    final risk = reading?['risk_level'] as String?;
    final bpm = reading?['bpm'];
    final spo2 = reading?['spo2'];
    final riskColor = _riskColor(risk);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RemoteMonitorScreen(patientId: p['id'], patientEmail: p['email'])),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar con estado
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: riskColor.withOpacity(0.15),
                    child: Icon(Icons.person_rounded, color: riskColor, size: 28),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(color: riskColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // Info del paciente
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['email'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
                    const SizedBox(height: 4),
                    if (reading != null)
                      Row(
                        children: [
                          const Icon(Icons.favorite_rounded, size: 13, color: Color(0xFFDC2626)),
                          const SizedBox(width: 3),
                          Text('$bpm BPM', style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
                          const SizedBox(width: 10),
                          const Icon(Icons.water_drop_rounded, size: 13, color: Color(0xFF2563EB)),
                          const SizedBox(width: 3),
                          Text('${spo2?.toStringAsFixed(1)}% SpO₂', style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
                        ],
                      )
                    else
                      const Text('Sin datos aún', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: riskColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(_riskLabel(risk), style: TextStyle(fontSize: 11, color: riskColor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('No tienes pacientes asignados aún.', style: TextStyle(color: Color(0xFF6B7280), fontSize: 15)),
          const SizedBox(height: 8),
          const Text('Un paciente debe registrarse con\ntu correo como supervisor.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
          const SizedBox(height: 20),
          TextButton.icon(
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Actualizar'),
            onPressed: _fetchPatients,
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 54, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          TextButton.icon(
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
            onPressed: _fetchPatients,
          ),
        ],
      ),
    );
  }
}
