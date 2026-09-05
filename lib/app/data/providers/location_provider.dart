import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../utils/env.dart';
import '../../services/auth_service.dart';

import '../models/location.dart';
import '../models/location_bulk.dart';
import '../models/location_results.dart';
import '../models/paginated_response.dart';
import '../models/userlastlocation.dart';

class LocationProvider {
  AuthService get _auth => Get.find<AuthService>();

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  String get _token => _auth.token.value;

  Future<Location> registerLocation({
    required String token,
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
    double? heading,
    double? batteryLevel,
    int? jornadaId,
    int? rutaId,
    bool isMocked = false,
    String source = 'mobile',
  }) async {
    final response = await http
        .post(
          Env.uri('/tracking/locations'),
          headers: _headers(token),
          body: jsonEncode({
            if (jornadaId != null) 'jornada_id': jornadaId,
            if (rutaId != null) 'ruta_id': rutaId,
            'latitude': latitude,
            'longitude': longitude,
            if (accuracy != null) 'accuracy': accuracy,
            if (speed != null) 'speed': speed,
            if (heading != null) 'heading': heading,
            if (batteryLevel != null) 'battery_level': batteryLevel,
            'is_mocked': isMocked,
            'source': source,
            'captured_at': DateTime.now().toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 8));

    final body = _decodeOrThrow(response, 'REGISTER_LOCATION');
    return Location.fromJson(body);
  }

  Future<LocationBulk> registerBulk({
    required String token,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await http
        .post(
          Env.uri('/tracking/locations/bulk'),
          headers: _headers(token),
          body: jsonEncode({'items': items}),
        )
        .timeout(const Duration(seconds: 8));

    final body = _decodeOrThrow(response, 'REGISTER_BULK');
    return LocationBulk.fromJson(body);
  }

  Future<LocationResult> getMyLastLocation({required String token}) async {
    final uri = Env.uri('/tracking/me/last-location');
    debugPrint('🌐 GET: $uri');
    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 8));
    final body = _decodeOrThrow(response, 'MY_LAST_LOCATION');
    return LocationResult.fromJson(body);
  }

  /// Historial real de ubicaciones.
  ///
  /// Para un Visitador Médico consulta su propio historial.
  /// Para Supervisor/Admin el backend valida si el user_id solicitado pertenece
  /// a su empresa/equipo.
  ///
  /// El fallback de "mi última ubicación" solo se usa cuando el usuario solicitado
  /// es el mismo usuario autenticado. De esta forma un Supervisor nunca verá su
  /// propia ubicación como si perteneciera al Visitador seleccionado.
  Future<PaginatedResponse<LocationResult>> getUserLocations({
    required int userId,
    int page = 1,
    int perPage = 500,
    String? from,
    String? to,
  }) async {
    Object? historyError;

    try {
      final historyUri = Env.uri('/tracking/locations', {
        'user_id': userId,
        'page': page,
        'per_page': perPage,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      });
      debugPrint('🌐 GET: $historyUri');

      final response = await http
          .get(historyUri, headers: _headers(_token))
          .timeout(const Duration(seconds: 8));

      final decoded = _decodeAnyOrThrow(response, 'USER_LOCATIONS');

      final rawItems =
          decoded is Map<String, dynamic> && decoded['data'] is List
          ? decoded['data'] as List
          : decoded is List
          ? decoded
          : <dynamic>[];

      final items =
          rawItems
              .whereType<Map>()
              .map(
                (item) =>
                    LocationResult.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((item) => _validCoordinate(item.latitude, item.longitude))
              .toList()
            ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));

      return PaginatedResponse<LocationResult>(
        currentPage: decoded is Map<String, dynamic>
            ? _toInt(decoded['current_page']) ?? 1
            : 1,
        data: items,
        from: items.isEmpty ? null : 1,
        lastPage: decoded is Map<String, dynamic>
            ? _toInt(decoded['last_page']) ?? 1
            : 1,
        nextPageUrl: null,
        perPage: decoded is Map<String, dynamic>
            ? _toInt(decoded['per_page']) ?? items.length
            : items.length,
        to: items.isEmpty ? null : items.length,
        total: decoded is Map<String, dynamic>
            ? _toInt(decoded['total']) ?? items.length
            : items.length,
      );
    } catch (e) {
      historyError = e;
      debugPrint('ℹ️ Historial completo no disponible: $e');
    }

    final authenticatedUserId = _auth.currentUser.value?.id;

    if (authenticatedUserId != userId) {
      throw Exception(
        'No se pudo cargar el historial del visitador $userId'
        '${historyError == null ? '' : ': $historyError'}',
      );
    }

    final last = await getMyLastLocation(token: _token);
    final valid = _validCoordinate(last.latitude, last.longitude);

    return PaginatedResponse<LocationResult>(
      currentPage: 1,
      data: valid ? [last] : [],
      from: valid ? 1 : null,
      lastPage: 1,
      nextPageUrl: null,
      perPage: valid ? 1 : 0,
      to: valid ? 1 : null,
      total: valid ? 1 : 0,
    );
  }

  /// Usuarios que el backend permite visualizar en seguimiento.
  ///
  /// Para Supervisor, /tracking/last-locations ya llega filtrado a los visitadores
  /// que tiene asignados. Se normalizan aquí los campos para alimentar el selector
  /// de "Recorridos" sin acoplar la interfaz al documento MongoDB.
  /// Visitadores Médicos que el backend permite supervisar.
  ///
  /// Para un Supervisor, /usuarios ya aplica supervisor_id = usuario autenticado,
  /// de modo que nunca expone visitadores de otro supervisor.
  /// Se consulta PostgreSQL y no last_locations para que también aparezcan
  /// visitadores offline o que todavía no tienen un punto GPS reciente.
  Future<List<Map<String, dynamic>>> getTrackableUsers() async {
    final uri = Env.uri('/usuarios', {
      'rol_id': 3,
      'est_id': 1,
      'per_page': 100,
    });
    debugPrint('🌐 GET visitadores asignados: $uri');

    final response = await http
        .get(uri, headers: _headers(_token))
        .timeout(const Duration(seconds: 8));

    final decoded = _decodeAnyOrThrow(response, 'TRACKABLE_USERS');
    final rawItems = decoded is Map<String, dynamic> && decoded['data'] is List
        ? decoded['data'] as List
        : decoded is List
        ? decoded
        : <dynamic>[];

    final users = <Map<String, dynamic>>[];

    for (final raw in rawItems.whereType<Map>()) {
      final item = Map<String, dynamic>.from(raw);
      final id = _toInt(item['usu_id'] ?? item['id']);
      if (id == null) continue;

      users.add({
        'id': id,
        'name': (item['usu_nombre'] ?? item['name'] ?? 'Visitador $id')
            .toString()
            .trim(),
        'email': (item['usu_email'] ?? item['email'] ?? '').toString(),
        'supervisor_id': _toInt(item['supervisor_id']),
        'role': item['rol'] is Map
            ? ((item['rol'] as Map)['rol_nombre'] ?? 'Visitador médico')
                  .toString()
            : 'Visitador médico',
      });
    }

    users.sort(
      (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
        (b['name'] ?? '').toString().toLowerCase(),
      ),
    );

    return users;
  }

  /// Ruta y puntos de visita asignados al Visitador para una fecha.
  /// El backend aplica automáticamente el alcance del Supervisor.
  Future<Map<String, dynamic>?> getAssignedRouteForDay({
    required int userId,
    required String date,
  }) async {
    final uri = Env.uri('/rutas', {
      'fecha': date,
      'visitador_id': userId,
      'per_page': 5,
    });
    debugPrint('🌐 GET ruta asignada: $uri');

    final response = await http
        .get(uri, headers: _headers(_token))
        .timeout(const Duration(seconds: 8));

    final decoded = _decodeAnyOrThrow(response, 'ASSIGNED_ROUTE');
    final rawItems = decoded is Map<String, dynamic> && decoded['data'] is List
        ? decoded['data'] as List
        : decoded is List
        ? decoded
        : <dynamic>[];

    if (rawItems.isEmpty || rawItems.first is! Map) return null;
    return Map<String, dynamic>.from(rawItems.first as Map);
  }

  /// Visitas registradas por un Visitador en una fecha.
  ///
  /// Se usa en Seguimiento para diferenciar el estado real de los puntos
  /// asignados. El backend mantiene el alcance por empresa/supervisor.
  Future<List<Map<String, dynamic>>> getVisitsForDay({
    required int userId,
    required String date,
  }) async {
    final uri = Env.uri('/visitas', {
      'desde': date,
      'hasta': date,
      'visitador_id': userId,
      'per_page': 200,
    });
    debugPrint('🌐 GET visitas del seguimiento: $uri');

    final response = await http
        .get(uri, headers: _headers(_token))
        .timeout(const Duration(seconds: 8));

    final decoded = _decodeAnyOrThrow(response, 'TRACKING_VISITS');
    final rawItems = decoded is Map<String, dynamic> && decoded['data'] is List
        ? decoded['data'] as List
        : decoded is List
        ? decoded
        : <dynamic>[];

    return rawItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<UserLastLocation>> getLastLocations() async {
    final uri = Env.uri('/tracking/last-locations');
    debugPrint('🌐 GET: $uri');
    final response = await http
        .get(uri, headers: _headers(_token))
        .timeout(const Duration(seconds: 8));

    final decoded = _decodeAnyOrThrow(response, 'LAST_LOCATIONS');
    final list = decoded is List
        ? decoded
        : decoded is Map<String, dynamic> && decoded['data'] is List
        ? decoded['data'] as List
        : <dynamic>[];

    return list
        .whereType<Map>()
        .map(
          (item) => UserLastLocation.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => _validCoordinate(item.latitude, item.longitude))
        .toList();
  }

  bool _validCoordinate(double lat, double lng) {
    return lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180 &&
        !(lat == 0 && lng == 0);
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  Map<String, dynamic> _decodeOrThrow(http.Response response, String tag) {
    final decoded = _decodeAnyOrThrow(response, tag);
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  }

  dynamic _decodeAnyOrThrow(http.Response response, String tag) {
    dynamic decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } catch (_) {
      decoded = {'message': response.body};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final message = decoded is Map<String, dynamic>
        ? (decoded['message'] ?? decoded['error'] ?? response.body).toString()
        : response.body;
    throw Exception('[$tag] ${response.statusCode}: $message');
  }
}
