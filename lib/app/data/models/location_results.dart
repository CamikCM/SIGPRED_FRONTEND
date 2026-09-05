class LocationResult {
  final double latitude;
  final double longitude;
  final DateTime capturedAt;
  final DateTime? updatedAt;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final String? source;

  LocationResult({
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.updatedAt,
    this.accuracy,
    this.speed,
    this.heading,
    this.source,
  });

  factory LocationResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;

    final geo = data['location'] is Map
        ? Map<String, dynamic>.from(data['location'] as Map)
        : null;
    final coords = geo?['coordinates'] is List
        ? geo!['coordinates'] as List
        : null;

    final lat =
        _toDouble(data['latitude']) ??
        (coords != null && coords.length >= 2 ? _toDouble(coords[1]) : null) ??
        0;
    final lng =
        _toDouble(data['longitude']) ??
        (coords != null && coords.length >= 2 ? _toDouble(coords[0]) : null) ??
        0;

    return LocationResult(
      latitude: lat,
      longitude: lng,
      capturedAt: _parseDate(data['captured_at']) ?? DateTime.now(),
      updatedAt: _parseDate(data['updated_at']),
      accuracy: _toDouble(data['accuracy']),
      speed: _toDouble(data['speed']),
      heading: _toDouble(data['heading']),
      source: data['source']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'captured_at': capturedAt.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    if (accuracy != null) 'accuracy': accuracy,
    if (speed != null) 'speed': speed,
    if (heading != null) 'heading': heading,
    if (source != null) 'source': source,
  };

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
