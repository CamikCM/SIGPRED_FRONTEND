class UserLastLocation {
  final int userId;
  final String name;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;
  final double? accuracy;
  final String? source;

  UserLastLocation({
    required this.userId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
    this.accuracy,
    this.source,
  });

  factory UserLastLocation.fromJson(Map<String, dynamic> json) {
    final geo = json['location'] is Map
        ? Map<String, dynamic>.from(json['location'] as Map)
        : null;
    final coords = geo?['coordinates'] is List
        ? geo!['coordinates'] as List
        : null;

    final userId = _toInt(json['user_id']) ?? 0;
    final lat =
        _toDouble(json['latitude']) ??
        (coords != null && coords.length >= 2 ? _toDouble(coords[1]) : null) ??
        0;
    final lng =
        _toDouble(json['longitude']) ??
        (coords != null && coords.length >= 2 ? _toDouble(coords[0]) : null) ??
        0;

    return UserLastLocation(
      userId: userId,
      name:
          (json['user_name'] ??
                  json['name'] ??
                  json['nombre'] ??
                  'Usuario $userId')
              .toString(),
      latitude: lat,
      longitude: lng,
      updatedAt:
          _parseDate(json['updated_at'] ?? json['captured_at']) ??
          DateTime.now(),
      accuracy: _toDouble(json['accuracy']),
      source: json['source']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'updated_at': updatedAt.toIso8601String(),
    if (accuracy != null) 'accuracy': accuracy,
    if (source != null) 'source': source,
  };

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString().replaceFirst(' ', 'T'));
  }
}
