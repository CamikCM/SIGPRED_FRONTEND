class Env {
  /// URL base de la API.
  ///
  /// Celular físico con adb reverse:
  /// adb reverse tcp:8000 tcp:8000
  /// flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
  ///
  /// Emulador Android:
  /// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
  ///
  /// Celular físico sin adb reverse:
  /// flutter run --dart-define=API_BASE_URL=http://IP_DE_TU_LAPTOP:8000/api
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api',
  );

  static Uri uri(String path, [Map<String, dynamic>? queryParameters]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final base = Uri.parse('$apiBaseUrl$cleanPath');
    if (queryParameters == null || queryParameters.isEmpty) return base;

    final qp = <String, String>{};
    queryParameters.forEach((key, value) {
      if (value != null) qp[key] = value.toString();
    });
    return base.replace(queryParameters: qp);
  }
}
