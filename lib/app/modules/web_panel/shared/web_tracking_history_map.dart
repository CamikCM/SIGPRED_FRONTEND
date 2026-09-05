export 'web_tracking_history_map_stub.dart'
    if (dart.library.html) 'web_tracking_history_map_web.dart';

enum WebAssignedVisitStatus { pending, completed, ineffective }

class WebAssignedVisitPoint {
  const WebAssignedVisitPoint({
    required this.order,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.clientId,
    this.plannedTime,
    this.status = WebAssignedVisitStatus.pending,
    this.visitTime,
    this.result,
    this.clientType,
    this.zoneName,
    this.address,
    this.phone,
    this.reference,
    this.orderAmount,
  });

  final int order;
  final String name;
  final double latitude;
  final double longitude;
  final int? clientId;
  final String? plannedTime;
  final WebAssignedVisitStatus status;
  final DateTime? visitTime;
  final String? result;
  final String? clientType;
  final String? zoneName;
  final String? address;
  final String? phone;
  final String? reference;
  final double? orderAmount;
}
