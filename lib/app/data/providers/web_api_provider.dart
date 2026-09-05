import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../services/auth_service.dart';
import '../../utils/env.dart';

class WebApiProvider {
  final http.Client _client = http.Client();

  AuthService get _auth => Get.find<AuthService>();

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_auth.token.value.isNotEmpty)
          'Authorization': 'Bearer ${_auth.token.value}',
      };

  Future<dynamic> get(String path, [Map<String, dynamic>? query]) async {
    final response = await _client.get(Env.uri(path, query), headers: _headers);
    return _decode(response, path);
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final response = await _client.post(
      Env.uri(path),
      headers: _headers,
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _decode(response, path);
  }

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) async {
    final response = await _client.put(
      Env.uri(path),
      headers: _headers,
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _decode(response, path);
  }

  Future<dynamic> delete(String path) async {
    final response = await _client.delete(Env.uri(path), headers: _headers);
    return _decode(response, path);
  }

  Future<Map<String, dynamic>> getMap(
    String path, [
    Map<String, dynamic>? query,
  ]) async {
    final decoded = await get(path, query);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {'data': decoded};
  }

  Future<List<dynamic>> getList(
    String path, [
    Map<String, dynamic>? query,
  ]) async {
    final decoded = await get(path, query);
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['data'] is List) {
      return decoded['data'] as List;
    }
    if (decoded is Map && decoded['items'] is List) {
      return decoded['items'] as List;
    }
    return <dynamic>[];
  }

  dynamic _decode(http.Response response, String tag) {
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

    final message = _errorMessage(decoded, response.body);
    throw Exception('[$tag] ${response.statusCode}: $message');
  }

  String _errorMessage(dynamic decoded, String fallback) {
    if (decoded is! Map) return fallback;

    if (decoded['errors'] is Map) {
      final errors = decoded['errors'] as Map;
      final messages = <String>[];
      for (final value in errors.values) {
        if (value is List) {
          messages.addAll(value.map((item) => item.toString()));
        } else if (value != null) {
          messages.add(value.toString());
        }
      }
      if (messages.isNotEmpty) return messages.join('\n');
    }

    return (decoded['message'] ?? decoded['error'] ?? fallback).toString();
  }
}
