class LocationBulk {
  final String message;
  final int inserted;

  LocationBulk({required this.message, required this.inserted});

  factory LocationBulk.fromJson(Map<String, dynamic> json) {
    return LocationBulk(
      message: (json['message'] ?? '').toString(),
      inserted: _toInt(json['inserted'] ?? json['total']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'message': message, 'inserted': inserted};

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
