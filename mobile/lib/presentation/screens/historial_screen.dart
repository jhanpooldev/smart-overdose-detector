// lib/presentation/screens/historial_screen.dart
//
// RF13 — Historial biométrico completo con:
//   - Descarga real de datos (exportar CSV en memoria)
//   - Cambios de estado del stream (CONNECTED / DISCONNECTED / etc.)
//   - statusMovement por lectura
//   - clinicalSuggestion por lectura
//   - Filtros de fecha (Última hora / Hoy / Últimos 7 días / Todo)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../infrastructure/api_client/api_client.dart';
import '../../infrastructure/auth/auth_service.dart';
import '../../domain/models/biometric_signal_model.dart';

class HistorialScreen extends StatefulWidget {
  /// Si se pasa [patientId], el supervisor consulta ese paciente.
  final String? patientId;
  final String? patientLabel;
  const HistorialScreen({super.key, this.patientId, this.patientLabel});
  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

// ── Filtros de rango temporal ──────────────────────────────────────────────────
enum _Range { lastHour, today, week, all }

extension _RangeExt on _Range {
  String get label => switch (this) {
    _Range.lastHour => 'Última hora',
    _Range.today    => 'Hoy',
    _Range.week     => '7 días',
    _Range.all      => 'Todo',
  };

  DateTime? get fromTs {
    final now = DateTime.now().toUtc();
    return switch (this) {
      _Range.lastHour => now.subtract(const Duration(hours: 1)),
      _Range.today    => DateTime.utc(now.year, now.month, now.day),
      _Range.week     => now.subtract(const Duration(days: 7)),
      _Range.all      => null,
    };
  }
}

class _HistorialScreenState extends State<HistorialScreen> {
  List<BiometricSignalResponse> _readings = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;
  _Range _range = _Range.today;
  final ApiClient _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final userId = widget.patientId ?? AuthService().currentUser?.id ?? '';
      if (userId.isEmpty) throw Exception('Sesión no iniciada');
      final list = await _api.getSignalHistory(
        patientId: userId,
        limit: 200,
        fromTs: _range.fromTs,
      );
      if (mounted) setState(() { _readings = list; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  // ── Exportar como CSV al portapapeles ─────────────────────────────────────
  Future<void> _exportCsv() async {
    if (_readings.isEmpty) return;
    setState(() => _isExporting = true);

    final sb = StringBuffer();
    sb.writeln('Fecha,Hora,BPM,SpO2,Resp,Movimiento,Estado_Stream,Riesgo,Alerta,Sugerencia');
    for (final r in _readings) {
      final dt = r.time.toLocal();
      final fecha = '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
      final hora  = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:${dt.second.toString().padLeft(2,'0')}';
      final sugerencia = r.clinicalSuggestion.replaceAll(',', ';');
      sb.writeln('$fecha,$hora,${r.heartRate},${r.spo2},${r.respRate ?? '-'},${r.statusMovement.label},${r.streamStatus},${r.riskLevel.label},${r.alertTriggered},$sugerencia');
    }

    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (mounted) {
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${_readings.length} registros copiados al portapapeles (CSV)'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.patientLabel != null ? ' — ${widget.patientLabel}' : '';
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : _error != null
              ? _buildError()
              : CustomScrollView(
                  slivers: [
                    // ── App bar con título y botón exportar ─────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Historial Biométrico$label',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    '${_readings.length} registros',
                                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            // Botón exportar CSV
                            _isExporting
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)))
                                : IconButton(
                                    icon: const Icon(Icons.download_rounded, color: Color(0xFF60A5FA)),
                                    tooltip: 'Exportar CSV al portapapeles',
                                    onPressed: _readings.isEmpty ? null : _exportCsv,
                                  ),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
                              onPressed: _fetchHistory,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Filtros de rango ────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _Range.values.map((r) {
                              final sel = r == _range;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _range = r);
                                    _fetchHistory();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: sel ? const Color(0xFF2563EB) : const Color(0xFF131929),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: sel ? const Color(0xFF2563EB) : Colors.white12,
                                      ),
                                    ),
                                    child: Text(
                                      r.label,
                                      style: TextStyle(
                                        color: sel ? Colors.white : Colors.white54,
                                        fontSize: 12,
                                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),

                    // ── Estadísticas rápidas ────────────────────────────────
                    if (_readings.isNotEmpty)
                      SliverToBoxAdapter(child: _buildStats()),

                    // ── Lista de lecturas ───────────────────────────────────
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: _readings.isEmpty
                          ? SliverFillRemaining(child: _buildEmpty())
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildCard(_readings[index]),
                                childCount: _readings.length,
                              ),
                            ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
    );
  }

  // ── Estadísticas rápidas ───────────────────────────────────────────────────
  Widget _buildStats() {
    final critCount = _readings.where((r) => r.riskLevel == RiskLevelV2.critical).length;
    final modCount  = _readings.where((r) => r.riskLevel == RiskLevelV2.moderate).length;
    final alertCount = _readings.where((r) => r.alertTriggered).length;

    // Cambios de estado del stream
    int stateChanges = 0;
    for (int i = 1; i < _readings.length; i++) {
      if (_readings[i].streamStatus != _readings[i-1].streamStatus) stateChanges++;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _statChip('Críticos', '$critCount', const Color(0xFFEF4444)),
          const SizedBox(width: 8),
          _statChip('Moderados', '$modCount', const Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          _statChip('Alertas', '$alertCount', const Color(0xFFEC4899)),
          const SizedBox(width: 8),
          _statChip('Cambios estado', '$stateChanges', const Color(0xFF8B5CF6)),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ── Card por lectura ───────────────────────────────────────────────────────
  Widget _buildCard(BiometricSignalResponse item) {
    final accent = item.riskLevel.color;
    final dt = item.time.toLocal();
    final timeStr =
        '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}  '
        '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:${dt.second.toString().padLeft(2,'0')}';

    // Color del stream status
    final streamColor = switch (item.streamStatus.toUpperCase()) {
      'CONNECTED' || 'ACTIVE' => const Color(0xFF10B981),
      'DISCONNECTED'          => Colors.white30,
      _                       => const Color(0xFFF59E0B),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.18), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera: tiempo + riesgo ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Container(
                  width: 4, height: 14,
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(timeStr, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                ),
                // Badge: alerta
                if (item.alertTriggered)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC4899).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('⚠ ALERTA', style: TextStyle(color: Color(0xFFEC4899), fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                // Badge: riesgo
                _pill(item.riskLevel.label.toUpperCase(), accent),
              ],
            ),
          ),

          // ── Métricas principales ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _pill('${item.heartRate} BPM', const Color(0xFFEC4899)),
                _pill('SpO₂ ${item.spo2.toStringAsFixed(0)}%', const Color(0xFF60A5FA)),
                if (item.respRate != null) _pill('${item.respRate} resp/min', const Color(0xFF34D399)),
                _pill(item.statusMovement.label, const Color(0xFFA78BFA)),
              ],
            ),
          ),

          // ── Estado del stream ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(color: streamColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  item.streamStatus,
                  style: TextStyle(color: streamColor, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                ),
              ],
            ),
          ),

          // ── Sugerencia clínica ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
            child: Text(
              item.clinicalSuggestion,
              style: TextStyle(
                color: item.riskLevel == RiskLevelV2.critical
                    ? const Color(0xFFFCA5A5)
                    : item.riskLevel == RiskLevelV2.moderate
                        ? const Color(0xFFFDE68A)
                        : Colors.white38,
                fontSize: 11,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.monitor_heart_rounded, size: 54, color: Colors.white12),
          const SizedBox(height: 16),
          Text(
            'No hay lecturas en el rango "${_range.label}".',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white30, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 8),
          const Text(
            'Conecta tu SmartWatch o cambia el filtro de fecha.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white24, fontSize: 12),
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
          const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.white24),
          const SizedBox(height: 16),
          Text(_error ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 24),
          TextButton.icon(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
            label: const Text('Reintentar', style: TextStyle(color: Color(0xFF2563EB))),
            onPressed: _fetchHistory,
          ),
        ],
      ),
    );
  }
}
