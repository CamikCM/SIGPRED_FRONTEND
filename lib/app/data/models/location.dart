class Location {
  final String message;
  final bool saved;
  final double? latitude;
  final double? longitude;
  final String? capturedAt;

  Location({
    required this.message,
    required this.saved,
    this.latitude,
    this.longitude,
    this.capturedAt,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    return Location(
      message: (json['message'] ?? 'Ubicación registrada').toString(),
      saved: true,
      latitude: _toDouble(data['latitude']),
      longitude: _toDouble(data['longitude']),
      capturedAt: data['captured_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'message': message,
    'saved': saved,
    'latitude': latitude,
    'longitude': longitude,
    'captured_at': capturedAt,
  };

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
