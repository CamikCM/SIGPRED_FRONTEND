import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../data/local/local_database.dart';
import '../utils/env.dart';
import 'auth_service.dart';

class SyncService extends GetxService {
  final LocalDatabase _localDb = LocalDatabase.instance;

  final isSyncing = false.obs;
  final pendingCount = 0.obs;
  final lastSyncMessage = 'Sincronización lista'.obs;

  AuthService get _auth => Get.find();

  Future<SyncService> init() async {
    await refreshPendingCount();
    return this;
  }

  Future<bool> hasConnection() async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  Future<void> refreshPendingCount() async {
    pendingCount.value = await _localDb.pendingCount();
  }

  Future<void> enqueue({
    required String kind,
    required String method,
    required String endpoint,
    required Map<String, dynamic> payload,
  }) async {
    await _localDb.insertOfflineRecord(
      kind: kind,
      method: method,
      endpoint: endpoint,
      payload: payload,
    );
    await refreshPendingCount();
    lastSyncMessage.value = 'Pendiente por sincronizar';
  }

  Future<void> enqueueVisita(Map<String, dynamic> payload) async {
    await enqueue(
      kind: 'visita',
      method: 'POST',
      endpoint: '/visitas',
      payload: payload,
    );
  }

  Future<bool> replacePendingVisita({
    required String localUuid,
    required Map<String, dynamic> payload,
  }) async {
    final replaced = await _localDb.replacePendingVisitaPayload(
      localUuid: localUuid,
      payload: payload,
    );
    await refreshPendingCount();
    if (replaced) {
      lastSyncMessage.value = 'Visita offline actualizada';
    }
    return replaced;
  }

  Future<void> enqueueVisitaUpdate({
    required int visitaId,
    required Map<String, dynamic> payload,
  }) async {
    await enqueue(
      kind: 'visita_update',
      method: 'PUT',
      endpoint: '/visitas/$visitaId',
      payload: payload,
    );
  }

  Future<void> enqueueJornadaInicio(Map<String, dynamic> payload) async {
    await enqueue(
      kind: 'jornada_inicio',
      method: 'POST',
      endpoint: '/jornadas/iniciar',
      payload: payload,
    );
  }

  Future<void> enqueueJornadaCierre(Map<String, dynamic> payload) async {
    await enqueue(
      kind: 'jornada_cierre',
      method: 'POST',
      endpoint: '/jornadas/cerrar',
      payload: payload,
    );
  }

  Future<void> enqueueTracking(Map<String, dynamic> payload) async {
    await enqueue(
      kind: 'tracking',
      method: 'POST',
      endpoint: '/tracking/locations',
      payload: payload,
    );
  }

  Future<int> syncPending() async {
    if (isSyncing.value) return 0;

    final token = _auth.token.value;
    if (token.isEmpty) {
      lastSyncMessage.value = 'Sin sesión activa';
      return 0;
    }

    // No se bloquea por Connectivity(). En pruebas con celular físico y adb reverse,
    // Android puede reportar sin WiFi/datos, pero el backend sí es accesible por USB.
    // Por eso se intenta enviar y, si falla HTTP, se conserva como pendiente.
    lastSyncMessage.value = 'Intentando sincronizar pendientes...';

    final records = await _localDb.pendingRecords(limit: 100);
    if (records.isEmpty) {
      lastSyncMessage.value = 'No hay pendientes';
      await refreshPendingCount();
      return 0;
    }

    isSyncing.value = true;
    var synced = 0;

    try {
      // Las operaciones comerciales conservan su orden lógico y tienen prioridad.
      // El tracking se procesa después en una sola petición bulk para evitar
      // decenas de POST consecutivos y respuestas 429 Too Many Attempts.
      final commercialRecords = records
          .where((record) => (record['kind'] ?? '').toString() != 'tracking')
          .toList();

      final trackingRecords = records
          .where((record) => (record['kind'] ?? '').toString() == 'tracking')
          .toList();

      for (final record in commercialRecords) {
        final id = _toInt(record['id']);
        if (id == null) continue;

        try {
          await _sendRecord(record, token);
          await _localDb.markSynced(id);
          synced += 1;
        } catch (e, st) {
          debugPrint('SYNC pendiente no enviado: $e\n$st');
          await _localDb.markFailed(id, e);

          // Jornadas y visitas mantienen orden lógico.
          // Si falla una operación comercial, no se intenta una posterior.
          break;
        }
      }

      // El tracking nunca debe bloquear la operación comercial.
      // Todos los puntos GPS de esta tanda se envían en una sola solicitud.
      if (trackingRecords.isNotEmpty) {
        try {
          await _sendTrackingBulk(trackingRecords, token);

          for (final record in trackingRecords) {
            final id = _toInt(record['id']);
            if (id == null) continue;
            await _localDb.markSynced(id);
            synced += 1;
          }
        } catch (e, st) {
          debugPrint('SYNC tracking bulk no enviado: $e\n$st');

          for (final record in trackingRecords) {
            final id = _toInt(record['id']);
            if (id == null) continue;
            await _localDb.markFailed(id, e);
          }
        }
      }
    } finally {
      isSyncing.value = false;
      await refreshPendingCount();
      lastSyncMessage.value = synced > 0
          ? 'Sincronizados: $synced. Pendientes: ${pendingCount.value}'
          : 'Pendientes: ${pendingCount.value}';
    }

    return synced;
  }

  Future<void> _sendTrackingBulk(
    List<Map<String, dynamic>> records,
    String token,
  ) async {
    final items = <Map<String, dynamic>>[];

    for (final record in records) {
      final payload = _decodePayload(record);
      items.add(payload);
    }

    if (items.isEmpty) return;

    final uri = Env.uri('/tracking/locations/bulk');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = await http
        .post(uri, headers: headers, body: jsonEncode({'items': items}))
        .timeout(const Duration(seconds: 15));

    _ensureSuccess(
      response,
      method: 'POST',
      endpoint: '/tracking/locations/bulk',
    );
  }

  Future<void> _sendRecord(Map<String, dynamic> record, String token) async {
    final method = (record['method'] ?? 'POST').toString().toUpperCase();
    final endpoint = (record['endpoint'] ?? '').toString();
    final payload = _decodePayload(record);
    final kind = (record['kind'] ?? '').toString();
    final recordUuid = (record['uuid'] ?? '').toString().trim();

    // Las visitas offline deben ser idempotentes. Si el teléfono recibe la respuesta
    // pero pierde conexión antes de marcar el registro como sincronizado, el reintento
    // no debe crear una segunda visita en PostgreSQL.
    if (kind == 'visita' && recordUuid.isNotEmpty) {
      payload.putIfAbsent('local_uuid', () => recordUuid);
    }

    final uri = Env.uri(endpoint);
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (recordUuid.isNotEmpty) 'X-Idempotency-Key': recordUuid,
    };

    late final http.Response response;

    switch (method) {
      case 'POST':
        response = await http
            .post(uri, headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 8));
        break;
      case 'PUT':
        response = await http
            .put(uri, headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 8));
        break;
      case 'PATCH':
        response = await http
            .patch(uri, headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 8));
        break;
      case 'DELETE':
        response = await http
            .delete(uri, headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 8));
        break;
      default:
        throw Exception('Método HTTP no soportado: $method');
    }

    _ensureSuccess(response, method: method, endpoint: endpoint);
  }

  Map<String, dynamic> _decodePayload(Map<String, dynamic> record) {
    final payloadText = (record['payload'] ?? '{}').toString();
    final decodedPayload = jsonDecode(payloadText);

    if (decodedPayload is! Map) {
      throw Exception('Payload local inválido');
    }

    return Map<String, dynamic>.from(decodedPayload);
  }

  void _ensureSuccess(
    http.Response response, {
    required String method,
    required String endpoint,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String message = response.body;

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        message = (decoded['message'] ?? decoded['error'] ?? response.body)
            .toString();
      }
    } catch (_) {}

    throw Exception(
      '[SYNC $method $endpoint] ${response.statusCode}: $message',
    );
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
