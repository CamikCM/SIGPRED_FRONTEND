import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../services/auth_service.dart';
import '../../utils/env.dart';

class VisitadorProvider {
  final http.Client _client = http.Client();

  AuthService get _auth => Get.find<AuthService>();

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (_auth.token.value.isNotEmpty)
      'Authorization': 'Bearer ${_auth.token.value}',
  };

  Future<Map<String, dynamic>?> getRutaHoy() async {
    final response = await _client.get(
      Env.uri('/me/ruta-hoy'),
      headers: _headers,
    );
    if (response.statusCode == 404) return null;
    return _decodeMap(response, 'RUTA_HOY');
  }

  Future<Map<String, dynamic>?> getJornadaHoy() async {
    final response = await _client.get(
      Env.uri('/me/jornada-hoy'),
      headers: _headers,
    );
    if (response.statusCode == 404) return null;
    return _decodeMap(response, 'JORNADA_HOY');
  }

  Future<List<Map<String, dynamic>>> getProductos() async {
    final response = await _client.get(
      Env.uri('/productos-disponibilidad'),
      headers: _headers,
    );
    final data = _decodeMap(response, 'CATALOGOS');
    final raw = data['productos'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> iniciarJornada({
    int? rutaId,
    double? lat,
    double? lng,
    String? observacion,
  }) async {
    final response = await _client.post(
      Env.uri('/jornadas/iniciar'),
      headers: _headers,
      body: jsonEncode({
        if (rutaId != null) 'ruta_id': rutaId,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (observacion != null && observacion.trim().isNotEmpty)
          'observacion': observacion.trim(),
      }),
    );
    return _decodeMap(response, 'INICIAR_JORNADA');
  }

  Future<Map<String, dynamic>> cerrarJornada({
    double? lat,
    double? lng,
    String? observacion,
  }) async {
    final response = await _client.post(
      Env.uri('/jornadas/cerrar'),
      headers: _headers,
      body: jsonEncode({
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (observacion != null && observacion.trim().isNotEmpty)
          'observacion': observacion.trim(),
      }),
    );
    return _decodeMap(response, 'CERRAR_JORNADA');
  }

  Future<Map<String, dynamic>> registrarVisita(
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.post(
      Env.uri('/visitas'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    return _decodeMap(response, 'REGISTRAR_VISITA');
  }

  Future<Map<String, dynamic>> actualizarVisita(
    int visitaId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.put(
      Env.uri('/visitas/$visitaId'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    return _decodeMap(response, 'ACTUALIZAR_VISITA');
  }

  Future<List<Map<String, dynamic>>> getHistorialVisitas({
    required String fecha,
    required int visitadorId,
    int perPage = 100,
  }) async {
    final uri = Env.uri('/visitas').replace(
      queryParameters: {
        'fecha': fecha,
        'visitador_id': visitadorId.toString(),
        'per_page': perPage.toString(),
      },
    );
    final response = await _client.get(uri, headers: _headers);
    final decoded = _decodeMap(response, 'HISTORIAL_VISITAS');
    final raw = decoded['data'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _decodeMap(http.Response response, String tag) {
    dynamic decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } catch (_) {
      decoded = {'message': response.body};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }

    final message = decoded is Map<String, dynamic>
        ? (decoded['message'] ?? decoded['error'] ?? response.body).toString()
        : response.body;
    throw Exception('[$tag] ${response.statusCode}: $message');
  }
}
