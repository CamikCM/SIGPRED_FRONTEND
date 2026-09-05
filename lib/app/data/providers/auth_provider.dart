import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../utils/env.dart';

class AuthProvider {
  final http.Client _client = http.Client();

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String deviceName = 'Flutter Mobile',
  }) async {
    final url = Env.uri('/login');
    final response = await _client.post(
      url,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'device_name': deviceName,
      }),
    );

    return _decodeOrThrow(response, 'LOGIN');
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String device,
    int empId = 1,
    int rolId = 3,
    int? supervisorId = 2,
    String? telefono,
  }) async {
    final payload = {
      'name': name,
      'nombre': name,
      'email': email,
      'password': password,
      'device': device,
      'emp_id': empId,
      'rol_id': rolId,
      'supervisor_id': supervisorId,
      if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
    };

    var response = await _client.post(
      Env.uri('/register'),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    // Compatibilidad con backend antiguo, donde la ruta era /register-dev.
    if (response.statusCode == 404) {
      response = await _client.post(
        Env.uri('/register-dev'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
    }

    return _decodeOrThrow(response, 'REGISTER');
  }

  Future<Map<String, dynamic>> logout({required String token}) async {
    final url = Env.uri('/logout');
    final response = await _client.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    return _decodeOrThrow(response, 'LOGOUT');
  }

  Map<String, dynamic> _decodeOrThrow(http.Response response, String tag) {
    final bodyText = response.body;
    dynamic decoded;
    try {
      decoded = bodyText.isEmpty ? <String, dynamic>{} : jsonDecode(bodyText);
    } catch (_) {
      decoded = {'message': bodyText};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }

    final message = decoded is Map<String, dynamic>
        ? (decoded['message'] ?? decoded['error'] ?? bodyText).toString()
        : bodyText;
    throw Exception('[$tag] ${response.statusCode}: $message');
  }
}
