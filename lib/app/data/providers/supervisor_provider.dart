import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'web_api_provider.dart';

class SupervisorProvider {
  WebApiProvider get _api => Get.find<WebApiProvider>();

  String _date(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

  Future<Map<String, dynamic>> resumenOperativo(DateTime fecha) async {
    return _api.getMap('/reportes/resumen-operativo', {
      'fecha': _date(fecha),
    });
  }

  Future<List<Map<String, dynamic>>> rutasHoy(DateTime fecha) async {
    final rows = await _api.getList('/supervisor/rutas-hoy', {
      'fecha': _date(fecha),
    });
    return rows
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> efectividadPorZona({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final rows = await _api.getList('/reportes/efectividad-zona', {
      'desde': _date(desde),
      'hasta': _date(hasta),
    });
    return rows
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
