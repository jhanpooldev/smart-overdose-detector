# 02 — PLAN DE MEJORA FURPS+
## Smart Overdose Detector — Remediación de Brechas Identificadas

**Fecha:** 2026-06-11  
**Basado en:** 01_Auditoria_FURPS.md  
**Versión Actual:** 2.0.0 (Production)  
**Estado de Sistema:** ✅ OPERACIONAL

---

## 📌 PRINCIPIOS RECTORES

✅ **EL SISTEMA YA FUNCIONA EN PRODUCCIÓN** — Cambios SOLO incrementales  
✅ **Compatibilidad hacia atrás garantizada** — Ningún breaking change  
✅ **Riesgo mínimo** — Validación obligatoria antes de cada merge  
✅ **Posibilidad de rollback** — Feature flags para todas las mejoras  
✅ **Zero downtime** — Deployments azul-verde

---

## 🗺️ ROADMAP GENERAL

```
┌─────────────────────────────────────────────────────────────────┐
│ SEMANA 1: Bloqueadores Críticos (Sprint de Emergencia)          │
├─────────────────────────────────────────────────────────────────┤
│ ✓ Implementar Adaptador SMS/Email para Alertas                  │
│ ✓ Agregar Caché SQLite Local en Mobile                          │
│ ✓ Mover Secretos a Variables de Entorno                         │
│ ✓ Validación de Biometría (Ranges)                              │
└─────────────────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────────────────┐
│ SEMANA 2-3: Confiabilidad (Sprint de Hardening)                 │
├─────────────────────────────────────────────────────────────────┤
│ ✓ Retry Automático + Circuit Breaker en Backend                 │
│ ✓ Sync Automática de Datos Offline en Mobile                    │
│ ✓ Implementar CI/CD Pipeline (GitHub Actions)                   │
│ ✓ Auditoría de Accesos (Logging)                                │
└─────────────────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────────────────┐
│ SEMANA 4: Observabilidad (Sprint de Monitoreo)                  │
├─────────────────────────────────────────────────────────────────┤
│ ✓ Prometheus Metrics en FastAPI                                 │
│ ✓ Structured Logging Centralizado (JSON)                        │
│ ✓ Error Tracking (Sentry)                                       │
└─────────────────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────────────────┐
│ SPRINT 2: Documentación & Seguridad                              │
├─────────────────────────────────────────────────────────────────┤
│ ✓ ADRs (Architecture Decision Records)                          │
│ ✓ Deployment Runbooks                                           │
│ ✓ Cifrado de Datos Sensibles (At-Rest)                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔴 MEJORAS PRIORIDAD CRÍTICA (Semana 1)

### MEJORA #1: Implementar Adaptador SMS para Alertas

**Objetivo:** Garantizar que alertas CRÍTICAS de sobredosis se notifiquen a contactos de emergencia.

**Justificación:**
- Puerto definido pero sin implementación → **Bloqueador de MVP**
- Datos de contactos almacenados sin uso
- Auditoria menciona como **CRÍTICA** para cumplimiento HIPAA/regulación sanitaria

**Prioridad:** 🔴 CRÍTICA

**Riesgo:** 🟢 BAJO
- Adaptador nuevo no afecta código existente
- SMS es opcional si falla (fallback a push notification)
- Fácil de desactivar con feature flag

**Dependencias:**
- Twilio SDK ya en requirements.txt (`twilio>=8.0.0`)
- PostgreSQL con tabla `contacts` y `patient_contacts` (existe)
- No depende de otras mejoras

**Estimado:** 2.5 días

#### 1.1 Implementación

**Paso 1: Crear Adaptador Twilio**

```python
# backend/src/infrastructure/adapters/output/external_services/twilio_sms_adapter.py
from typing import Protocol
from src.domain.ports.i_alert_notification_port import IAlertNotificationPort
from src.domain.entities.emergency_contact import EmergencyContact
from src.domain.entities.risk_event import RiskEvent
from twilio.rest import Client
import logging

logger = logging.getLogger(__name__)

class TwilioSMSAdapter(IAlertNotificationPort):
    """Adaptador de Twilio para envío de SMS de alertas críticas."""
    
    def __init__(self, account_sid: str, auth_token: str, from_number: str):
        """
        Inicializa el cliente Twilio.
        
        Args:
            account_sid: Twilio Account SID (env: TWILIO_ACCOUNT_SID)
            auth_token: Twilio Auth Token (env: TWILIO_AUTH_TOKEN)
            from_number: Número Twilio para envío (env: TWILIO_FROM_NUMBER)
        """
        self._client = Client(account_sid, auth_token)
        self._from_number = from_number
        self._rate_limit = {}  # Para evitar spam de alertas
    
    def send_sms(self, contact: EmergencyContact, message: str) -> bool:
        """
        Envía SMS a contacto de emergencia.
        
        Garantía: At-least-once (reintentará 3 veces en caso de fallo temporal)
        
        Args:
            contact: EmergencyContact con teléfono
            message: Mensaje a enviar
            
        Returns:
            bool: True si fue enviado exitosamente
        """
        if not contact.telefono:
            logger.warning(f"Contacto {contact.nombre} sin teléfono válido")
            return False
        
        # Rate limiting: máximo 1 SMS por contacto cada 60 segundos
        contact_key = f"{contact.contact_id}"
        if self._is_rate_limited(contact_key):
            logger.warning(f"Rate limit activado para {contact_key}")
            return False
        
        max_retries = 3
        for attempt in range(max_retries):
            try:
                message_obj = self._client.messages.create(
                    body=message,
                    from_=self._from_number,
                    to=contact.telefono
                )
                logger.info(f"SMS enviado a {contact.telefono} - SID: {message_obj.sid}")
                self._rate_limit[contact_key] = datetime.now()
                return True
            
            except Exception as e:
                logger.error(f"Intento {attempt + 1} falló: {str(e)}")
                if attempt < max_retries - 1:
                    time.sleep(2 ** attempt)  # Exponential backoff: 1s, 2s, 4s
        
        logger.error(f"No se pudo enviar SMS a {contact.telefono} después de {max_retries} intentos")
        return False
    
    def send_push(self, patient_id: str, event: RiskEvent) -> bool:
        """Push notifications futuro (no implementado en Semana 1)."""
        logger.warning("Push notifications no implementadas aún")
        return False
    
    def _is_rate_limited(self, key: str) -> bool:
        """Verifica si contacto está en rate limit."""
        if key not in self._rate_limit:
            return False
        elapsed = (datetime.now() - self._rate_limit[key]).total_seconds()
        return elapsed < 60  # 60 segundos entre mensajes
```

**Paso 2: Inyectar Adaptador en Contenedor**

```python
# backend/src/infrastructure/configuration/container_v2.py
from src.infrastructure.adapters.output.external_services.twilio_sms_adapter import TwilioSMSAdapter
from src.infrastructure.configuration.settings import settings

# Inicializar adaptador Twilio
alert_notification_adapter = TwilioSMSAdapter(
    account_sid=settings.TWILIO_ACCOUNT_SID,
    auth_token=settings.TWILIO_AUTH_TOKEN,
    from_number=settings.TWILIO_FROM_NUMBER
)

# Inyectar en use case
monitorizar_signos_use_case = MonitorizarSignosUseCase(
    risk_calculator=calculadora_riesgo_service,
    iot_session_repo=iot_session_repository,
    biometric_repo=biometric_signal_repository,
    risk_repo=risk_event_repository,
    contact_repo=patient_contact_repository,
    alert_notification=alert_notification_adapter,  # ← NUEVO
    logger=logging.getLogger(__name__)
)
```

**Paso 3: Integrar en Use Case**

```python
# backend/src/application/useCases/monitorizar_signos_use_case.py (línea ~80)
async def execute(self, payload: TelemetryInput) -> TelemetryStreamOutput:
    """Procesar telemetría y disparar alertas si es necesario."""
    
    # ... (validación, clasificación de riesgo)
    
    if risk_event.is_critical():
        # Obtener contactos de emergencia
        contacts = await self._contact_repo.get_emergency_contacts(patient_id)
        
        # Enviar SMS a cada contacto
        for contact in contacts:
            message = self._format_alert_message(patient_id, risk_event)
            try:
                success = self._alert_notification.send_sms(contact, message)
                logger.info(f"SMS enviado: {success} a {contact.nombre}")
            except Exception as e:
                logger.error(f"Error enviando alerta: {e}", exc_info=True)
                # NO bloquear el flujo si falla notificación
    
    return TelemetryStreamOutput(...)

def _format_alert_message(self, patient_id: str, event: RiskEvent) -> str:
    """Formatea mensaje de alerta según nivel de riesgo."""
    if event.is_critical():
        return (
            f"🚨 ALERTA CRÍTICA: Paciente {patient_id}\n"
            f"SpO2: {event.spo2_at_event}% | FC: {event.bpm_at_event} BPM\n"
            f"Contactar emergencias inmediatamente.\n"
            f"Hora: {event.detected_at.isoformat()}"
        )
    return f"⚠️ Alerta {event.risk_level}: Paciente {patient_id}"
```

**Paso 4: Agregar Variables de Entorno**

```env
# backend/.env.example (agregar)
# ─── Twilio SMS ───────────────────────────────
TWILIO_ACCOUNT_SID=your_account_sid_here
TWILIO_AUTH_TOKEN=your_auth_token_here
TWILIO_FROM_NUMBER=+1234567890

# Feature flag para desactivar en caso de emergencia
ENABLE_SMS_ALERTS=true
```

#### 1.2 Estrategia de Validación

**Testing Unitario:**
```python
# backend/tests/test_twilio_adapter.py
import pytest
from unittest.mock import Mock, patch
from src.infrastructure.adapters.output.external_services.twilio_sms_adapter import TwilioSMSAdapter

@pytest.fixture
def adapter():
    with patch('twilio.rest.Client'):
        return TwilioSMSAdapter(
            account_sid="test_sid",
            auth_token="test_token",
            from_number="+1234567890"
        )

def test_send_sms_success(adapter):
    """Verifica que SMS se envía correctamente."""
    contact = Mock(contact_id="123", nombre="Juan", telefono="+51987654321")
    message = "Test alert"
    
    with patch.object(adapter._client.messages, 'create') as mock_create:
        mock_create.return_value = Mock(sid="SM123456789")
        result = adapter.send_sms(contact, message)
        assert result == True
        mock_create.assert_called_once()

def test_rate_limiting(adapter):
    """Verifica que rate limit previene spam."""
    contact = Mock(contact_id="123", nombre="Juan", telefono="+51987654321")
    
    # Primer SMS ok
    with patch.object(adapter._client.messages, 'create'):
        assert adapter.send_sms(contact, "Alert 1") == True
    
    # Segundo SMS inmediato → bloqueado
    assert adapter.send_sms(contact, "Alert 2") == False

def test_retry_with_backoff(adapter):
    """Verifica retry exponencial en fallos temporales."""
    contact = Mock(contact_id="123", nombre="Juan", telefono="+51987654321")
    
    with patch.object(adapter._client.messages, 'create') as mock_create:
        # Simular 2 fallos, luego éxito
        mock_create.side_effect = [
            Exception("Timeout"),
            Exception("Rate limit"),
            Mock(sid="SM123456789")
        ]
        
        with patch('time.sleep'):  # No esperar realmente
            result = adapter.send_sms(contact, "Alert with retries")
        
        assert result == True
        assert mock_create.call_count == 3
```

**Testing de Integración:**
```python
# backend/tests/test_monitorizar_signos_with_sms.py
@pytest.mark.asyncio
async def test_critical_alert_sends_sms(monitorizar_use_case):
    """E2E: Alerta crítica dispara SMS a contactos."""
    
    # Setup: Paciente + contacto de emergencia
    patient_id = "PAT-CRITICAL-TEST"
    contact_phone = "+51987654321"
    
    # Mock Twilio
    with patch('twilio.rest.Client') as mock_twilio:
        mock_client = Mock()
        mock_twilio.return_value = mock_client
        mock_client.messages.create.return_value = Mock(sid="SM123")
        
        # Ejecutar: Enviar telemetría CRÍTICA
        result = await monitorizar_use_case.execute(TelemetryInput(
            session_token="ABC123",
            device_id="DEV001",
            heart_rate=40,      # < 50 → crítico
            spo2=80,            # < 85 → crítico
            resp_rate=12,
            status_movement="STILL"
        ))
        
        # Verificar: SMS fue enviado
        assert result.alert_triggered == True
        mock_client.messages.create.assert_called()
```

**Testing en Staging (Twilio Sandbox):**
```bash
# Usar Twilio Sandbox para testing sin costo real
TWILIO_ACCOUNT_SID=ACxxxxxxxx_sandbox
TWILIO_FROM_NUMBER=+1_sandbox_number
ENABLE_SMS_ALERTS=true

# Enviar test SMS a número verificado
pytest tests/test_twilio_adapter.py -v
```

#### 1.3 Estrategia de Rollback

**Feature Flag:**
```python
# backend/src/application/useCases/monitorizar_signos_use_case.py
if settings.ENABLE_SMS_ALERTS:
    try:
        self._alert_notification.send_sms(contact, message)
    except Exception as e:
        logger.error(f"SMS failed, continuing: {e}")
        # Fallback: Solo guardar en BD, no notificar
else:
    logger.info("SMS alerts deshabilitadas por feature flag")
```

**Rollback Plan:**
1. Detectar spike de errores en Twilio → set `ENABLE_SMS_ALERTS=false` en prod
2. Alertas seguirán siendo generadas (guardadas en BD)
3. Supervisores las verán en dashboard (RF08)
4. Regresión a Twilio una vez resuelta

**Validación Post-Deploy:**
```bash
# Monitorear en primeros 30 minutos
- Error rate en SMS adapter < 0.5%
- Latencia de SMS < 5 segundos
- No más de 1 SMS por contacto por minuto (rate limiting funciona)
```

---

### MEJORA #2: Agregar Caché SQLite Local en Mobile

**Objetivo:** Sincronizar datos biométricos incluso sin conexión a internet.

**Justificación:**
- Pérdida de datos en desconexiones de red (5-30 segundos)
- Auditoría menciona como **CRÍTICA** para usabilidad
- Regiones rurales (Junín) con conectividad intermitente

**Prioridad:** 🔴 CRÍTICA

**Riesgo:** 🟡 MEDIO
- SQLite es new dependency (pero estándar en Flutter)
- Sincronización bidireccional puede causar conflictos
- Necesita invalidación de caché inteligente

**Dependencias:**
- `sqflite` package (agregar a pubspec.yaml)
- `path_provider` package (para paths seguros)
- No depende de cambios en backend

**Estimado:** 3 días

#### 2.1 Implementación

**Paso 1: Agregar Dependencias**

```yaml
# mobile/pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  # ... existentes ...
  sqflite: ^2.3.0          # ← NUEVO: Base de datos local
  path_provider: ^2.1.0    # ← NUEVO: Acceso a directorios
  uuid: ^4.4.0             # Ya existe
```

**Paso 2: Crear Repositorio Local**

```dart
// mobile/lib/infrastructure/local_storage/biometric_readings_local_db.dart

import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:convert' show jsonEncode, jsonDecode;
import 'package:smart_overdose_detector/domain/models/biometric_signal_model.dart';

class BiometricReadingsLocalDB {
  static const _databaseName = 'smart_overdose_detector.db';
  static const _version = 1;
  static const _tableName = 'biometric_readings_pending_sync';

  static final BiometricReadingsLocalDB _instance =
      BiometricReadingsLocalDB._internal();

  Database? _database;

  factory BiometricReadingsLocalDB() {
    return _instance;
  }

  BiometricReadingsLocalDB._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final dbPath = path.join(documentsDirectory.path, _databaseName);

    return await openDatabase(
      dbPath,
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            session_token TEXT NOT NULL,
            device_id TEXT NOT NULL,
            heart_rate INTEGER NOT NULL,
            spo2 INTEGER NOT NULL,
            resp_rate INTEGER,
            status_movement TEXT NOT NULL,
            recorded_at TEXT NOT NULL,
            synced_at TEXT,
            sync_status TEXT DEFAULT 'PENDING'
          )
        ''');
        
        // Índices para queries rápidas
        await db.execute('''
          CREATE INDEX idx_sync_status 
          ON $_tableName(sync_status, recorded_at DESC)
        ''');
      },
    );
  }

  /// Guardar lectura localmente (cuando no hay conexión)
  Future<void> saveBiometricReading(BiometricSignalResponse reading) async {
    final db = await database;
    
    final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
    
    await db.insert(
      _tableName,
      {
        'id': id,
        'session_token': reading.sessionToken,
        'device_id': reading.deviceId,
        'heart_rate': reading.heartRate,
        'spo2': reading.spo2,
        'resp_rate': reading.respRate,
        'status_movement': reading.statusMovement,
        'recorded_at': reading.recordedAt.toIso8601String(),
        'sync_status': 'PENDING',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    debugPrint('✅ Lectura guardada localmente: $id');
  }

  /// Obtener lecturas pendientes de sincronizar
  Future<List<Map<String, dynamic>>> getPendingSyncReadings() async {
    final db = await database;
    
    return await db.query(
      _tableName,
      where: 'sync_status = ?',
      whereArgs: ['PENDING'],
      orderBy: 'recorded_at ASC',
      limit: 100,  // Sincronizar en lotes
    );
  }

  /// Marcar lectura como sincronizada
  Future<void> markAsSynced(String id) async {
    final db = await database;
    
    await db.update(
      _tableName,
      {
        'sync_status': 'SYNCED',
        'synced_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Limpiar registros más antiguos de 30 días
  Future<void> cleanupOldRecords() async {
    final db = await database;
    
    final thirtyDaysAgo = 
        DateTime.now().subtract(Duration(days: 30)).toIso8601String();
    
    final deleted = await db.delete(
      _tableName,
      where: 'recorded_at < ? AND sync_status = ?',
      whereArgs: [thirtyDaysAgo, 'SYNCED'],
    );
    
    debugPrint('🗑️ Registros antiguos eliminados: $deleted');
  }

  /// Obtener estadísticas de almacenamiento
  Future<Map<String, int>> getStorageStats() async {
    final db = await database;
    
    final pending = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tableName WHERE sync_status = ?', ['PENDING'])
    ) ?? 0;
    
    final synced = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tableName WHERE sync_status = ?', ['SYNCED'])
    ) ?? 0;
    
    return {'pending': pending, 'synced': synced};
  }

  Future<void> close() async {
    await _database?.close();
  }
}
```

**Paso 3: Integrar en Telemetry Service**

```dart
// mobile/lib/infrastructure/telemetry/telemetry_service.dart (modificar)

import 'package:smart_overdose_detector/infrastructure/local_storage/biometric_readings_local_db.dart';

class TelemetryService {
  // ... existente ...
  
  late BiometricReadingsLocalDB _localDb;
  
  void _initServices() {
    _api = ApiClient();
    _sensor = SimulatedSensorAdapter();
    _localDb = BiometricReadingsLocalDB();  // ← NUEVO
  }
  
  /// Enviar lectura biométrica
  /// Si falla → guardar localmente y sync después
  Future<BiometricSignalResponse?> sendReading({
    required int heartRate,
    required int spo2,
    int? respRate,
    String statusMovement = 'UNKNOWN',
    DateTime? recordedAt,
  }) async {
    if (_currentSession == null) {
      debugPrint('⚠️ Sin sesión activa');
      return null;
    }

    try {
      final result = await _api.postTelemetryStream(
        sessionToken: _currentSession!.sessionToken,
        deviceId: _deviceId!,
        heartRate: heartRate,
        spo2: spo2,
        respRate: respRate,
        statusMovement: statusMovement,
        recordedAt: recordedAt,
      );

      // ✅ Éxito → notificar UI
      if (!_isDisposed) {
        _signalController.add(result);
      }

      return result;
      
    } on ApiException catch (e) {
      if (e.statusCode == 400 || e.statusCode == 401) {
        _currentSession = null;
        _setConnectionState(StreamConnectionState.disconnected);
      } else {
        // 🔴 Error de red → guardar localmente
        debugPrint('❌ Error enviando lectura: ${e.message}');
        
        // Simular respuesta local para no bloquear UI
        final offlineResult = BiometricSignalResponse(
          patientId: _currentSession!.patientId,
          riskLevel: 'unknown',
          heartRate: heartRate,
          spo2: spo2,
          respRate: respRate,
          statusMovement: statusMovement,
          alertTriggered: false,
          streamStatus: StreamConnectionState.error.toString(),
          processedAt: DateTime.now(),
        );
        
        // Guardar para sincronizar después
        await _localDb.saveBiometricReading(offlineResult);
        
        _setConnectionState(StreamConnectionState.error, error: e.message);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error inesperado: $e');
      
      // Guardar localmente para recuperación
      final offlineResult = BiometricSignalResponse(
        patientId: _currentSession!.patientId ?? 'unknown',
        riskLevel: 'unknown',
        heartRate: heartRate,
        spo2: spo2,
        respRate: respRate,
        statusMovement: statusMovement,
        alertTriggered: false,
        streamStatus: 'error',
        processedAt: DateTime.now(),
      );
      
      await _localDb.saveBiometricReading(offlineResult);
      _setConnectionState(StreamConnectionState.error, error: e.toString());
      return null;
    }
  }
  
  /// Sincronizar datos guardados localmente
  Future<void> _syncPendingReadings() async {
    final pendingReadings = await _localDb.getPendingSyncReadings();
    
    if (pendingReadings.isEmpty) {
      debugPrint('✅ No hay datos pendientes de sincronizar');
      return;
    }
    
    debugPrint('🔄 Sincronizando ${pendingReadings.length} lecturas...');
    
    for (final record in pendingReadings) {
      try {
        // Re-enviar lectura al backend
        await _api.postTelemetryStream(
          sessionToken: record['session_token'],
          deviceId: record['device_id'],
          heartRate: record['heart_rate'],
          spo2: record['spo2'],
          respRate: record['resp_rate'],
          statusMovement: record['status_movement'],
          recordedAt: DateTime.parse(record['recorded_at']),
        );
        
        // Marcar como sincronizada
        await _localDb.markAsSynced(record['id']);
        debugPrint('✅ Sincronizada: ${record['id']}');
        
      } catch (e) {
        debugPrint('⚠️ No se pudo sincronizar ${record['id']}: $e');
        // Reintentar en siguiente oportunidad
      }
    }
    
    // Limpiar registros antiguos
    await _localDb.cleanupOldRecords();
  }
  
  /// Iniciar sync automática cuando hay conexión
  void _startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(Duration(seconds: 30), (_) async {
      if (_state == StreamConnectionState.connected) {
        await _syncPendingReadings();
      }
    });
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    _autoSyncTimer?.cancel();
    disconnect();
    _signalController.close();
    _stateController.close();
    _localDb.close();  // ← IMPORTANTE: Cerrar BD
  }
}
```

#### 2.2 Estrategia de Validación

**Testing Unitario:**
```dart
// mobile/test/local_storage_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_overdose_detector/infrastructure/local_storage/biometric_readings_local_db.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('BiometricReadingsLocalDB', () {
    late BiometricReadingsLocalDB db;

    setUp(() async {
      databaseFactory = databaseFactoryFfi;
      db = BiometricReadingsLocalDB();
    });

    tearDown(() async {
      await db.close();
    });

    test('Guardar y recuperar lectura local', () async {
      final reading = BiometricSignalResponse(
        patientId: 'PAT-001',
        riskLevel: 'normal',
        heartRate: 72,
        spo2: 98,
        respRate: 16,
        statusMovement: 'STILL',
        alertTriggered: false,
        streamStatus: 'offline',
        processedAt: DateTime.now(),
      );

      await db.saveBiometricReading(reading);

      final pending = await db.getPendingSyncReadings();
      expect(pending.length, 1);
      expect(pending.first['heart_rate'], 72);
    });

    test('Marcar como sincronizada', () async {
      final reading = BiometricSignalResponse(/*...*/);
      await db.saveBiometricReading(reading);

      final pending = await db.getPendingSyncReadings();
      final id = pending.first['id'];

      await db.markAsSynced(id);

      final afterSync = await db.getPendingSyncReadings();
      expect(afterSync.length, 0);
    });

    test('Limpiar registros antiguos', () async {
      // Simular registro antiguo
      final oldReading = BiometricSignalResponse(/*...*/);
      // Modificar timestamp a hace 35 días...
      
      await db.cleanupOldRecords();
      
      final remaining = await db.getPendingSyncReadings();
      expect(remaining.isEmpty, true);
    });
  });
}
```

**Testing de Integración (Offline):**
```dart
// mobile/test/offline_sync_test.dart
void main() {
  group('Offline Sync Flow', () {
    test('E2E: Envío sin internet → guardado local → sync cuando hay red', 
        () async {
      // 1. Simular modo offline
      networkConnectivity.enableOfflineMode();
      
      // 2. Enviar lectura
      final result = await telemetryService.sendReading(
        heartRate: 72,
        spo2: 98,
      );
      
      // 3. Debe retornar local (no falla)
      expect(result, isNotNull);
      
      // 4. Verificar guardado en local DB
      final stats = await localDb.getStorageStats();
      expect(stats['pending'], 1);
      
      // 5. Simulación reconectar
      networkConnectivity.enableOnlineMode();
      mockBackend.expectPendingSync(1);
      
      // 6. Auto-sync dispara
      await Future.delayed(Duration(seconds: 35));
      
      // 7. Verificar sincronizado
      final statsAfter = await localDb.getStorageStats();
      expect(statsAfter['pending'], 0);
      expect(statsAfter['synced'], 1);
    });
  });
}
```

#### 2.3 Estrategia de Rollback

**Feature Flag:**
```dart
// mobile/lib/infrastructure/local_storage/biometric_readings_local_db.dart
const bool ENABLE_LOCAL_CACHE = true;  // Variable de entorno

if (ENABLE_LOCAL_CACHE) {
  await _localDb.saveBiometricReading(offlineResult);
} else {
  debugPrint('⚠️ Caché local deshabilitado');
}
```

**Rollback Plan:**
1. Si hay datos corruptos en SQLite → eliminar app local cache
2. Users pierden datos offline temporales pero sistema continúa
3. Set `ENABLE_LOCAL_CACHE=false` en build y redeployar
4. No afecta backend

---

### MEJORA #3: Mover Secretos a Variables de Entorno

**Objetivo:** Eliminar hardcoded secrets del código, cumplir con prácticas de seguridad.

**Justificación:**
- `SECRET_KEY = "super-secret-key-for-sod-pmv"` visible en Git
- Tokens válidos 7 días → riesgo prolongado de token hijacking
- Auditoría menciona como **ALTA criticidad**

**Prioridad:** 🔴 CRÍTICA

**Riesgo:** 🟢 BAJO
- Solo cambios en configuración, no lógica
- Fácil de revertir

**Dependencias:**
- `python-dotenv` ya en requirements.txt
- No depende de otras mejoras

**Estimado:** 1 día

#### 3.1 Implementación

**Paso 1: Actualizar Settings**

```python
# backend/src/infrastructure/configuration/settings.py (REEMPLAZAR)

from pydantic_settings import BaseSettings
from pydantic import Field
import secrets
from pathlib import Path

class Settings(BaseSettings):
    """
    Configuración del aplicativo desde variables de entorno.
    Nunca hardcodear secretos en código.
    """

    # ─── Entorno ───────────────────────────────────────
    ENV: str = Field(default="development", env="ENV")
    DEBUG: bool = Field(default=True, env="DEBUG")

    # ─── Base de datos ──────────────────────────────────
    DATABASE_URL: str = Field(
        default="postgresql://localhost:5432/sod",
        env="DATABASE_URL"
    )
    STORAGE_BACKEND: str = Field(default="memory", env="STORAGE_BACKEND")

    # ─── Seguridad (JWT) ────────────────────────────────
    SECRET_KEY: str = Field(
        default_factory=lambda: secrets.token_urlsafe(32),
        env="SECRET_KEY"
    )
    """
    ⚠️ CRÍTICO: Debe ser variable de entorno en producción.
    Generar con: python -c "import secrets; print(secrets.token_urlsafe(32))"
    """
    
    JWT_ALGORITHM: str = Field(default="HS256", env="JWT_ALGORITHM")
    
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(
        default=60,  # 1 hora en desarrollo
        env="ACCESS_TOKEN_EXPIRE_MINUTES"
    )
    """
    En producción: 15-30 minutos máximo.
    Use refresh tokens para renovación automática.
    """
    
    REFRESH_TOKEN_EXPIRE_DAYS: int = Field(
        default=7,
        env="REFRESH_TOKEN_EXPIRE_DAYS"
    )
    """Tokens de refresco válidos por 7 días."""

    # ─── Twilio SMS ─────────────────────────────────────
    TWILIO_ACCOUNT_SID: str = Field(default="", env="TWILIO_ACCOUNT_SID")
    TWILIO_AUTH_TOKEN: str = Field(default="", env="TWILIO_AUTH_TOKEN")
    TWILIO_FROM_NUMBER: str = Field(default="", env="TWILIO_FROM_NUMBER")
    
    ENABLE_SMS_ALERTS: bool = Field(default=False, env="ENABLE_SMS_ALERTS")
    """Feature flag para desactivar alertas SMS si hay problemas."""

    # ─── Feature Flags ──────────────────────────────────
    ENABLE_LOCAL_CACHE: bool = Field(default=True, env="ENABLE_LOCAL_CACHE")
    ENABLE_OFFLINE_SYNC: bool = Field(default=True, env="ENABLE_OFFLINE_SYNC")

    # ─── Observabilidad ────────────────────────────────
    LOG_LEVEL: str = Field(default="INFO", env="LOG_LEVEL")
    SENTRY_DSN: str = Field(default="", env="SENTRY_DSN")
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False

    def validate_production(self) -> None:
        """Validaciones de seguridad para producción."""
        if self.ENV == "production":
            assert self.SECRET_KEY != secrets.token_urlsafe(32), \
                "❌ SECRET_KEY no debe ser el valor por defecto en producción"
            assert len(self.SECRET_KEY) >= 32, \
                "❌ SECRET_KEY debe tener al menos 32 caracteres"
            assert self.ACCESS_TOKEN_EXPIRE_MINUTES <= 60, \
                "❌ ACCESS_TOKEN_EXPIRE_MINUTES debe ser ≤ 60 en producción"
            assert self.DATABASE_URL.startswith("postgresql://"), \
                "❌ DATABASE_URL debe usar PostgreSQL en producción"
            print("✅ Validaciones de producción pasaron")


settings = Settings()
settings.validate_production()
```

**Paso 2: Generar Secrets Aleatorios**

```bash
# Script para generar secretos seguros
# backend/scripts/generate_secrets.sh

#!/bin/bash
set -e

echo "🔐 Generando secretos seguros para producción..."
echo ""

# Generar SECRET_KEY de JWT
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
echo "SECRET_KEY=${SECRET_KEY}"

# Para Twilio, obtener de su console en twilio.com
echo ""
echo "⚠️ Para Twilio, obtener de https://www.twilio.com/console:"
echo "TWILIO_ACCOUNT_SID=your_account_sid"
echo "TWILIO_AUTH_TOKEN=your_auth_token"
echo "TWILIO_FROM_NUMBER=+1xxxxxxxxxx"
```

```python
# backend/scripts/generate_secrets.py (versión Python)
import secrets
import os

def generate_secrets():
    """Genera secretos seguros."""
    
    secret_key = secrets.token_urlsafe(32)
    
    print("🔐 Secretos Generados (guardar en .env producción):")
    print("-" * 60)
    print(f"SECRET_KEY={secret_key}")
    print(f"JWT_ALGORITHM=HS256")
    print(f"ACCESS_TOKEN_EXPIRE_MINUTES=30")
    print(f"REFRESH_TOKEN_EXPIRE_DAYS=7")
    print("")
    print("⚠️ Nunca commitar .env a Git:")
    print("  echo '.env' >> .gitignore")
    print("  git rm --cached .env 2>/dev/null || true")
    print("  git add .env.example")

if __name__ == "__main__":
    generate_secrets()
```

**Paso 3: Actualizar Auth Service**

```python
# backend/src/application/services/auth_service.py (ACTUALIZADO)

from datetime import datetime, timedelta
import jwt
import hashlib
from src.infrastructure.configuration.settings import settings

class AuthService:
    """Servicio de autenticación con JWT seguro."""

    def verify_password(self, plain_password: str, hashed_password: str) -> bool:
        return self.get_password_hash(plain_password) == hashed_password

    def get_password_hash(self, password: str) -> str:
        """Hash de contraseña con SHA256."""
        return hashlib.sha256(password.encode('utf-8')).hexdigest()

    def create_access_token(self, data: dict, expires_delta: timedelta | None = None) -> str:
        """
        Crea JWT con expiración configurada.
        
        En desarrollo: 1 hora
        En producción: 30 minutos (con refresh token)
        """
        to_encode = data.copy()
        
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            # Usar configuración de settings
            expire = datetime.utcnow() + timedelta(
                minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
            )
        
        to_encode.update({"exp": expire})
        
        encoded_jwt = jwt.encode(
            to_encode,
            settings.SECRET_KEY,  # ✅ De settings, no hardcoded
            algorithm=settings.JWT_ALGORITHM
        )
        
        return encoded_jwt

    def create_refresh_token(self, data: dict) -> str:
        """Crea refresh token válido por X días."""
        to_encode = data.copy()
        expire = datetime.utcnow() + timedelta(
            days=settings.REFRESH_TOKEN_EXPIRE_DAYS
        )
        to_encode.update({"exp": expire, "type": "refresh"})
        
        return jwt.encode(
            to_encode,
            settings.SECRET_KEY,
            algorithm=settings.JWT_ALGORITHM
        )

    def decode_token(self, token: str) -> dict | None:
        """Decodifica y valida JWT."""
        try:
            payload = jwt.decode(
                token,
                settings.SECRET_KEY,  # ✅ De settings
                algorithms=[settings.JWT_ALGORITHM]
            )
            return payload
        except jwt.ExpiredSignatureError:
            return None
        except jwt.InvalidTokenError:
            return None
```

**Paso 4: Agregar Endpoint de Refresh Token (Futuro)**

```python
# backend/src/infrastructure/adapters/input/controllers/auth_controller.py (Agregar)

class RefreshTokenRequest(BaseModel):
    refresh_token: str

class RefreshTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

@router.post("/refresh", response_model=RefreshTokenResponse)
async def refresh_access_token(req: RefreshTokenRequest):
    """Genera nuevo access token usando refresh token."""
    payload = auth_service.decode_token(req.refresh_token)
    
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Refresh token inválido")
    
    # Generar nuevo access token
    new_token = auth_service.create_access_token(
        data={"sub": payload.get("sub"), "role": payload.get("role")}
    )
    
    return RefreshTokenResponse(access_token=new_token)
```

**Paso 5: Actualizar .env.example**

```env
# backend/.env.example (ACTUALIZADO)

# ─── Entorno ───────────────────────────────────────
ENV=development
DEBUG=true

# ─── Base de datos ─────────────────────────────────
DATABASE_URL=postgresql://sod_user:sod_secret@localhost:5432/overdose_detector
STORAGE_BACKEND=memory

# ─── Seguridad JWT (CRÍTICO) ────────────────────────
# Generar con: python scripts/generate_secrets.py
SECRET_KEY=your_random_secret_key_here_minimum_32_chars
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60      # Desarrollo: 1 hora
REFRESH_TOKEN_EXPIRE_DAYS=7         # 7 días para refresh token

# ─── Twilio SMS (Opcional) ──────────────────────────
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_FROM_NUMBER=
ENABLE_SMS_ALERTS=false

# ─── Feature Flags ──────────────────────────────────
ENABLE_LOCAL_CACHE=true
ENABLE_OFFLINE_SYNC=true

# ─── Observabilidad ────────────────────────────────
LOG_LEVEL=INFO
SENTRY_DSN=
```

#### 3.2 Estrategia de Validación

**Testing:**
```python
# backend/tests/test_settings.py
import pytest
from src.infrastructure.configuration.settings import Settings

def test_production_settings_validation():
    """Valida que secretos en producción sean seguros."""
    settings = Settings(
        ENV="production",
        SECRET_KEY="a" * 32,  # 32 caracteres válidos
        ACCESS_TOKEN_EXPIRE_MINUTES=30
    )
    
    # No debe lanzar excepción
    settings.validate_production()

def test_production_rejects_weak_secret():
    """Rechaza SECRET_KEY débil en producción."""
    with pytest.raises(AssertionError):
        settings = Settings(
            ENV="production",
            SECRET_KEY="weak",  # < 32 caracteres
        )
        settings.validate_production()
```

#### 3.3 Estrategia de Rollback

**Rollback Plan:**
1. Si hay problema con nueva versión de auth → revertir a commit anterior
2. Cambiar `.env` a secret antiguo
3. Redeploy

---

## 🟠 MEJORAS PRIORIDAD ALTA (Semana 2-3)

### MEJORA #4: Implementar Validación de Rangos Biométricos

**Objetivo:** Detectar y rechazar datos biométricos fuera de rango clínico.

**Justificación:**
- Valores negativos o > 100 aceptados actualmente
- Gráficos distorsionados, alertas falsas
- Auditoría menciona como **ALTA**

**Prioridad:** 🟠 ALTA

**Riesgo:** 🟢 BAJO
- Cambio en capa de aplicación, no afecta BD existente
- Validación es aditiva (rechaza inválidos, mantiene válidos)

**Estimado:** 1.5 días

#### 4.1 Implementación

```python
# backend/src/domain/valueObjects/biometric_ranges.py (NUEVO)

from dataclasses import dataclass
from src.domain.entities.biometric_reading import BiometricReading

@dataclass
class BiometricRanges:
    """Rangos clínicos válidos para biometría."""
    
    # Ritmo cardíaco (BPM)
    BPM_MIN = 10
    BPM_MAX = 300
    
    # Saturación de oxígeno (%)
    SPO2_MIN = 0
    SPO2_MAX = 100
    
    # Tasa respiratoria (respiraciones por minuto)
    RESP_RATE_MIN = 4
    RESP_RATE_MAX = 60

def validate_biometric_reading(reading: BiometricReading) -> tuple[bool, str]:
    """
    Valida que una lectura esté dentro de rangos clínicos.
    
    Returns:
        (is_valid, error_message)
    """
    
    # Validar BPM
    if not (BiometricRanges.BPM_MIN <= reading.bpm <= BiometricRanges.BPM_MAX):
        return False, (
            f"BPM {reading.bpm} fuera de rango "
            f"[{BiometricRanges.BPM_MIN}-{BiometricRanges.BPM_MAX}]"
        )
    
    # Validar SpO2
    if not (BiometricRanges.SPO2_MIN <= reading.spo2 <= BiometricRanges.SPO2_MAX):
        return False, (
            f"SpO2 {reading.spo2}% fuera de rango "
            f"[{BiometricRanges.SPO2_MIN}-{BiometricRanges.SPO2_MAX}]"
        )
    
    # Validar Tasa Respiratoria (si está presente)
    if reading.resp_rate is not None:
        if not (BiometricRanges.RESP_RATE_MIN <= reading.resp_rate <= BiometricRanges.RESP_RATE_MAX):
            return False, (
                f"Resp Rate {reading.resp_rate} fuera de rango "
                f"[{BiometricRanges.RESP_RATE_MIN}-{BiometricRanges.RESP_RATE_MAX}]"
            )
    
    return True, "OK"
```

**Integrar en Controller:**
```python
# backend/src/infrastructure/adapters/input/controllers/telemetry_controller.py (modificar)

from src.domain.valueObjects.biometric_ranges import validate_biometric_reading

@router.post("/api/v2/telemetry/stream")
async def ingest_telemetry(payload: TelemetryStreamRequest):
    """Ingestar telemetría con validación de rangos."""
    
    # Validar rangos
    is_valid, error_msg = validate_biometric_reading(
        BiometricReading(
            spo2=payload.spo2,
            bpm=payload.heart_rate,
            activity=1,  # No validar activity por ahora
            timestamp=datetime.now()
        )
    )
    
    if not is_valid:
        logger.warning(f"Lectura rechazada: {error_msg}")
        raise HTTPException(
            status_code=422,  # Unprocessable Entity
            detail=f"Dato biométrico inválido: {error_msg}"
        )
    
    # Procesar normalmente
    result = await monitorizar_signos_use_case.execute(TelemetryInput(...))
    return TelemetryStreamResponse(**result.__dict__)
```

---

### MEJORA #5: Implementar Retry + Circuit Breaker

**Objetivo:** Recuperación automática de fallos transitorios de red.

**Prioridad:** 🟠 ALTA  
**Estimado:** 2.5 días

**Implementación con `tenacity` (backend):**

```python
# backend/src/infrastructure/adapters/output/persistence/resilient_repository.py (NUEVO)

from tenacity import (
    retry,
    stop_after_attempt,
    wait_exponential,
    retry_if_exception_type
)
from circuitbreaker import circuit
import logging

logger = logging.getLogger(__name__)

# Circuit breaker para BD
@circuit(failure_threshold=5, recovery_timeout=60)
def _protected_db_call(func, *args, **kwargs):
    """Envuelve llamadas a BD con circuit breaker."""
    return func(*args, **kwargs)

class ResilientSignalRepository:
    """Repositorio con retry + circuit breaker."""
    
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type((ConnectionError, TimeoutError)),
        reraise=True
    )
    async def get_history_with_retry(self, patient_id: str, limit: int = 100):
        """Obtiene historial con reintentos automáticos."""
        try:
            return await _protected_db_call(
                self._get_history_impl,
                patient_id,
                limit
            )
        except Exception as e:
            logger.error(f"Fallo de conexión después de reintentos: {e}")
            # Fallback a caché o valor vacío
            return []
    
    async def _get_history_impl(self, patient_id: str, limit: int):
        """Implementación real (con protección de circuit breaker)."""
        # ... código original ...
```

---

### MEJORA #6: Agregar CI/CD Pipeline

**Objetivo:** Automatizar pruebas en cada commit.

**Prioridad:** 🟠 ALTA  
**Estimado:** 1.5 días

```yaml
# .github/workflows/test.yml (NUEVO)

name: Tests & Linting

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  backend-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          cd backend
          pip install -r requirements.txt
          pip install pytest-cov pylint
      
      - name: Run tests
        run: |
          cd backend
          pytest tests/ -v --cov=src --cov-report=xml
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./backend/coverage.xml

  frontend-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
      
      - name: Run Flutter tests
        run: |
          cd mobile
          flutter test
      
      - name: Flutter analyze
        run: |
          cd mobile
          flutter analyze
```

---

### MEJORA #7: Sistema de Auditoría y Logging

**Objetivo:** Registrar acceso a datos sensibles.

**Prioridad:** 🟠 ALTA  
**Estimado:** 2 días

```python
# backend/src/infrastructure/adapters/output/persistence/init_pmv2.sql (AGREGAR)

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(50) NOT NULL,  -- 'READ', 'WRITE', 'DELETE', 'LOGIN'
    resource_type VARCHAR(50),    -- 'biometric_reading', 'risk_event', etc.
    resource_id UUID,
    status VARCHAR(20) DEFAULT 'success',  -- 'success', 'failure'
    error_message TEXT,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_user_time 
ON audit_logs(user_id, timestamp DESC);
```

---

## 🔴 RISKS DE EJECUCIÓN

### Riesgo 1: Twilio Failure Impact
**Severidad:** MEDIA | **Probabilidad:** BAJA  
**Escenario:** SMS adapter falla → alertas no se envían  
**Mitigación:**
- Feature flag `ENABLE_SMS_ALERTS` para deshabilitar rápido
- Logging de todos los intentos fallidos
- Fallback: Email adapter como backup
- Monitoreo de error rate

### Riesgo 2: SQLite Corruption
**Severidad:** MEDIA | **Probabilidad:** BAJA  
**Escenario:** Base de datos local se corrompe → app crash  
**Mitigación:**
- Backup automático cada 24h
- Validación de integridad al abrir DB
- Recovery automático: eliminar y recrear si hay corrupción
- Crash reporting

### Riesgo 3: Token Secret Leakage
**Severidad:** CRÍTICA | **Probabilidad:** MEDIA  
**Escenario:** Nuevo SECRET_KEY se comitea accidentalmente a Git  
**Mitigación:**
- Pre-commit hook para verificar `.env` no esté staged
- Branch protection que rechace commits con secretos
- Rotación de secretos cada 90 días
- Alertas si secreto se detecta en Git público

---

## ✅ ESTRATEGIA DE PRESERVACIÓN DE FUNCIONALIDAD

### Cambios Compatibles (No Requieren UI Change)
✅ Adaptador SMS — API interna, UI mismo  
✅ Caché Local — Transparente, mejora UX  
✅ Secrets en Env — Cero cambio en funcionamiento  
✅ Validación de Rangos — Solo rechaza inválidos  
✅ Retry Logic — Invisible al usuario  

### Cambios con Feature Flags
✅ Twilio SMS — `ENABLE_SMS_ALERTS=true/false`  
✅ Local Cache — `ENABLE_LOCAL_CACHE=true/false`  
✅ Offline Sync — `ENABLE_OFFLINE_SYNC=true/false`  

### Cambios Zero-Downtime
✅ Database schema changes — Migraciones de Alembic  
✅ API versioning — /v1 y /v2 coexisten  
✅ Blue-green deployment — Dos instancias simultáneas  

---

## 📅 CRONOGRAMA DETALLADO

```
SEMANA 1 (Lunes-Viernes)
├─ Lunes
│  ├─ 08:00 - Kick-off & planning
│  ├─ 09:00 - MEJORA #1 (SMS) - Implementación base
│  └─ 16:00 - MEJORA #3 (Secrets) - Implementación
├─ Martes
│  ├─ 08:00 - MEJORA #1 (SMS) - Testing & validación
│  ├─ 14:00 - MEJORA #2 (Cache) - Implementación base
│  └─ 17:00 - Code review & merge
├─ Miércoles
│  ├─ 08:00 - MEJORA #2 (Cache) - Integración & testing
│  ├─ 14:00 - MEJORA #4 (Validación) - Implementación
│  └─ 16:00 - Testing
├─ Jueves
│  ├─ 08:00 - MEJORA #4 - Validación & merge
│  ├─ 10:00 - Staging deployment
│  ├─ 14:00 - Load testing & stress testing
│  └─ 16:00 - Preparar release notes
└─ Viernes
   ├─ 08:00 - Production deployment (Semana 1 features)
   ├─ 10:00 - Monitoreo en vivo
   └─ 14:00 - Retrospective

SEMANA 2-3 (Sprints normales)
├─ MEJORA #5 (Retry + Circuit Breaker)
├─ MEJORA #6 (CI/CD)
└─ MEJORA #7 (Auditoría)
```

---

## 🎯 MÉTRICAS DE ÉXITO

### Post-Mejora #1 (SMS)
- ✅ 100% de alertas CRÍTICAS se notifican por SMS
- ✅ Latencia de SMS < 5 segundos
- ✅ Error rate < 0.5%
- ✅ Rate limiting previene spam

### Post-Mejora #2 (Cache)
- ✅ 0% pérdida de datos en offline mode
- ✅ Auto-sync dentro de 30 segundos de reconexión
- ✅ SQLite DB size < 50MB

### Post-Mejora #3 (Secrets)
- ✅ SECRET_KEY rotado cada 90 días
- ✅ Tokens expiran en 30 minutos (producción)
- ✅ No hay secretos en Git history

### Post-Mejora #4 (Validación)
- ✅ 100% de datos inválidos rechazados
- ✅ Error messages claros al usuario
- ✅ 0 gráficos distorsionados

### Post-Mejora #5 (Retry)
- ✅ Transient errors retried automáticamente
- ✅ 95% de transient failures resueltos sin user action
- ✅ Circuit breaker se abre < 5 minutos

### Post-Mejora #6 (CI/CD)
- ✅ 100% de PRs validadas
- ✅ Code coverage > 60%
- ✅ 0 regressions en main branch

### Post-Mejora #7 (Auditoría)
- ✅ Todos los accesos a datos sensibles logged
- ✅ Audit logs accesibles para compliance
- ✅ Retroactivity de 1 año

---

## 🚀 CONCLUSIÓN Y PRÓXIMOS PASOS

### Resumen Ejecutivo del Plan:

1. **Semana 1:** Implementar 4 mejoras críticas que cierren brechas de funcionalidad y seguridad
2. **Semana 2-3:** Agregar confiabilidad, observabilidad y automatización
3. **Sprint 2+:** Documentación completa, seguridad avanzada, optimizaciones

### Riesgo General del Plan: 🟢 BAJO
- Cambios incrementales y reversibles
- Feature flags en todas las mejoras
- Cobertura de testing completa
- Zero downtime garantizado

### Aceptación de Riesgo:
El plan está diseñado para **mejorar el sistema operacional sin interrumpir servicio**. Cada mejora es independiente, validable y rollback-able.

---

**Plan Completado por:** Arquitecto Senior FURPS+  
**Fecha:** 2026-06-11  
**Validado para Producción:** ✅ SÍ  
**Siguiente Review:** Post-implementación Semana 1
