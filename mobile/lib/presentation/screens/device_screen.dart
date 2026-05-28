// lib/presentation/screens/device_screen.dart
//
// RF08 — Estado de conexión del dispositivo wearable (SmartWatch Simulator).
// Crea sesión IoT, muestra token de emparejamiento y hace polling cada 4s.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../infrastructure/api_client/api_client.dart';
import '../../infrastructure/telemetry/telemetry_service.dart';
import '../../domain/models/iot_session_model.dart';
import 'monitor_screen_v2.dart';
import 'home_shell.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});
  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen>
    with SingleTickerProviderStateMixin {
  // ── Servicios ──────────────────────────────────────────────────────────────
  final ApiClient _api = ApiClient();

  // ── Estado ─────────────────────────────────────────────────────────────────
  IoTSessionModel? _session;
  bool _isCreating = false;
  String? _error;
  Timer? _pollingTimer;

  // ── Animación de pulso ─────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    // Animación de pulso para el indicador verde
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Reutilizar sesión existente del TelemetryService (si ya está activa)
    final existing = TelemetryService().currentSession;
    if (existing != null) {
      _session = existing;
      _startPolling();
    } else {
      _createSession();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ── Crear sesión IoT ───────────────────────────────────────────────────────
  Future<void> _createSession() async {
    setState(() { _isCreating = true; _error = null; });
    try {
      final session = await _api.createIoTSession();
      if (mounted) {
        setState(() { _session = session; _isCreating = false; });
        _startPolling();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() { _error = e.detail ?? e.message; _isCreating = false; });
        _showSnackBar(e.detail ?? e.message, isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _isCreating = false; });
        _showSnackBar('Error inesperado al crear sesión', isError: true);
      }
    }
  }

  // ── Polling cada 4 segundos ────────────────────────────────────────────────
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollStatus(); // inmediato
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pollStatus());
  }

  Future<void> _pollStatus() async {
    if (_session == null || !mounted) return;
    try {
      final updated = await _api.getSessionStatus(_session!.sessionToken);
      if (mounted) {
        final wasActive = _isActive;
        setState(() => _session = updated);
        if (!wasActive && _isActive) {
          _showSnackBar('¡Dispositivo conectado exitosamente!');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MonitorScreenV2()),
          );
        }
      }
    } catch (_) {
      // Silencioso — no interrumpir la UI por fallo temporal de polling
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _copyToken() {
    if (_session == null) return;
    Clipboard.setData(ClipboardData(text: _session!.sessionToken));
    _showSnackBar('Token copiado al portapapeles ✓');
  }

  bool get _isActive => _session?.streamStatus == 'ACTIVE' || _session?.isActive == true;

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.watch_rounded, size: 22, color: Colors.white),
            SizedBox(width: 8),
            Text('Dispositivo SmartWatch',
                style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Actualizar estado',
            onPressed: _isCreating ? null : _pollStatus,
          ),
        ],
      ),
      body: _isCreating ? _buildLoading() : _buildContent(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF2563EB)),
          SizedBox(height: 16),
          Text('Creando sesión IoT...', style: TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // ── Status Indicator ────────────────────────────────────────────────
        _buildStatusIndicator(),
        const SizedBox(height: 20),

        // ── Pairing Card ────────────────────────────────────────────────────
        _buildPairingCard(),
        const SizedBox(height: 20),

        // ── Connection Info Card ────────────────────────────────────────────
        _buildConnectionInfoCard(),
        const SizedBox(height: 20),

        // ── CTA: Ver monitor en vivo (solo si ACTIVE) ───────────────────────
        if (_isActive) _buildGoToMonitorButton(),
        if (_isActive) const SizedBox(height: 12),

        // ── Botón Regenerar token ───────────────────────────────────────────
        _buildRegenerateButton(),
      ],
    );
  }

  // ── Widget: Indicador de estado pulsante ───────────────────────────────────
  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (_isActive ? const Color(0xFF10B981) : Colors.white12),
          width: _isActive ? 1 : 0,
        ),
      ),
      child: Row(
        children: [
          // Dot pulsante
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) {
              final color = _isActive ? const Color(0xFF10B981) : Colors.white24;
              return Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isActive ? color.withOpacity(_pulseAnim.value) : color,
                  boxShadow: _isActive
                      ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8, spreadRadius: 2)]
                      : null,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isActive ? 'SmartWatch conectado ✓' : 'Esperando conexión…',
                  style: TextStyle(
                    color: _isActive ? const Color(0xFF10B981) : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (_session != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Estado: ${_session!.streamStatus}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          // Chip del estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (_isActive ? const Color(0xFF10B981) : Colors.white12).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isActive ? 'ACTIVO' : 'INACTIVO',
              style: TextStyle(
                color: _isActive ? const Color(0xFF10B981) : Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widget: Token de emparejamiento ───────────────────────────────────────
  Widget _buildPairingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.link_rounded, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 8),
              Text('Empareja tu SmartWatch',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Ingresa este código en el simulador web:',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse('https://smartwatch-simulator-production.up.railway.app');
              // Solo informativo — url_launcher no está disponible sin permisos en todos los contextos
            },
            child: const Text(
              'smartwatch-simulator-production.up.railway.app →',
              style: TextStyle(
                color: Color(0xFF60A5FA),
                fontSize: 11,
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFF60A5FA),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Token en monospace grande
          if (_session != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0E1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  _session!.sessionToken,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 8,
                  ),
                ),
              ),
            )
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12))),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Botón Copiar token
          if (_session != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _copyToken,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copiar código', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Botón Confirmar (Simular)
          if (_session != null && !_isActive)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _pollingTimer?.cancel();
                  TelemetryService().startSimulation();
                  homeShellKey.currentState?.switchToTab(0);
                },
                icon: const Icon(Icons.science_rounded, size: 18, color: Color(0xFF10B981)),
                label: const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF10B981)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Widget: Info de conexión ──────────────────────────────────────────────
  Widget _buildConnectionInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        children: [
          _infoRow(Icons.watch_rounded, 'Wearable',
              _isActive ? 'Conectado' : 'Desconectado',
              _isActive ? const Color(0xFF10B981) : Colors.white38),
          const Divider(color: Colors.white12, height: 1),
          _infoRow(Icons.cloud_rounded, 'Servidor',
              _session != null ? 'En línea' : 'Sin sesión',
              _session != null ? const Color(0xFF2563EB) : Colors.white38),
          const Divider(color: Colors.white12, height: 1),
          _infoRow(Icons.refresh_rounded, 'Polling',
              'Cada 4 segundos', Colors.white54),
          if (_session?.lastHeartbeat != null) ...[
            const Divider(color: Colors.white12, height: 1),
            _infoRow(Icons.schedule_rounded, 'Último latido',
                _formatTime(_session!.lastHeartbeat!), Colors.white54),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color valueColor) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: valueColor, size: 20),
      title: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      trailing: Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  // ── Widget: Botón ir al monitor ────────────────────────────────────────────
  Widget _buildGoToMonitorButton() {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MonitorScreenV2()),
        );
      },
      icon: const Icon(Icons.monitor_heart_rounded, size: 20),
      label: const Text('Ver monitor en vivo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ── Widget: Regenerar token ────────────────────────────────────────────────
  Widget _buildRegenerateButton() {
    return OutlinedButton.icon(
      onPressed: _isCreating ? null : () {
        _pollingTimer?.cancel();
        _createSession();
      },
      icon: const Icon(Icons.autorenew_rounded, size: 18, color: Colors.white54),
      label: const Text('Regenerar token', style: TextStyle(color: Colors.white54, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.white12),
        minimumSize: const Size(double.infinity, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
  }
}
