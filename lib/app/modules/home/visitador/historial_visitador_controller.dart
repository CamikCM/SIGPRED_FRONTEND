import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/local/local_database.dart';
import '../../../data/models/visita_historial.dart';
import '../../../data/providers/visitador_provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/sync_service.dart';
import '../../../utils/safe_ui.dart';
import 'visitador_operativo_controller.dart';

class HistorialVisitadorController extends GetxController {
  final VisitadorProvider _provider = Get.find<VisitadorProvider>();
  final AuthService _auth = Get.find<AuthService>();
  final LocalDatabase _localDb = LocalDatabase.instance;

  SyncService? get _sync =>
      Get.isRegistered<SyncService>() ? Get.find<SyncService>() : null;

  final isLoading = false.obs;
  final isRemoteLoading = false.obs;
  final backendDisponible = true.obs;
  final backendMensaje = ''.obs;

  final visitas = <VisitaHistorial>[].obs;
  final registrosOffline = <Map<String, dynamic>>[].obs;
  final selectedDate = DateTime.now().obs;
  final selectedFilter = 'todas'.obs;
  final searchText = ''.obs;
  final dateController = TextEditingController();
  final searchController = TextEditingController();

  static const filters = <String>[
    'todas',
    'efectivas',
    'no_efectivas',
    'pendientes',
  ];

  @override
  void onInit() {
    super.onInit();
    dateController.text = DateFormat('yyyy-MM-dd').format(selectedDate.value);
    searchController.addListener(
      () => searchText.value = searchController.text.trim(),
    );
  }

  Future<void> cargarHistorial() async {
    if (isLoading.value || isRemoteLoading.value) return;

    final user = _auth.currentUser.value;
    if (user == null) {
      SafeUi.snackbar('Historial de visitas', 'No existe una sesión activa.');
      return;
    }

    final fecha = DateFormat('yyyy-MM-dd').format(selectedDate.value);
    List<VisitaHistorial> localRows = <VisitaHistorial>[];

    // Primero se leen los registros del teléfono. Así las visitas pendientes
    // siguen visibles aunque el backend esté desconectado o tarde en responder.
    try {
      isLoading.value = true;
      final localResults = await Future.wait<dynamic>([
        _localDb.recordsByKind(
          kind: 'visita',
          statuses: const ['pending'],
          limit: 300,
        ),
        _localDb.offlineRecords(
          statuses: const ['pending', 'synced'],
          limit: 150,
        ),
      ]);

      localRows = _offlineVisitsForDate(
        localResults[0] as List<Map<String, dynamic>>,
        selectedDate.value,
      );
      registrosOffline.assignAll(localResults[1] as List<Map<String, dynamic>>);
      visitas.assignAll(localRows);
    } catch (e) {
      backendMensaje.value =
          'No se pudo leer el almacenamiento local: ${_cleanError(e)}';
    } finally {
      isLoading.value = false;
    }

    // Después se consulta PostgreSQL. Si falla, no se eliminan los registros
    // locales ya cargados y el filtro Pendientes continúa funcionando.
    try {
      isRemoteLoading.value = true;
      final apiData = await _provider.getHistorialVisitas(
        fecha: fecha,
        visitadorId: user.id,
        perPage: 100,
      );
      final apiRows = apiData.map(VisitaHistorial.fromApi).toList();
      final combined = <VisitaHistorial>[...apiRows, ...localRows]
        ..sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));
      visitas.assignAll(combined);
      backendDisponible.value = true;
      backendMensaje.value = '';
    } catch (e) {
      backendDisponible.value = false;
      backendMensaje.value = _cleanError(e);
      // Se conserva el contenido local. No se muestra snackbar repetitivo,
      // porque la pantalla ya informa que trabaja con datos del teléfono.
    } finally {
      isRemoteLoading.value = false;
    }
  }

  Future<void> cargarRegistrosOffline() async {
    try {
      final rows = await _localDb.offlineRecords(
        statuses: const ['pending', 'synced'],
        limit: 150,
      );
      registrosOffline.assignAll(rows);
    } catch (e) {
      SafeUi.snackbar('Datos offline', _cleanError(e));
    }
  }

  Future<void> pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.value,
      firstDate: DateTime(now.year - 5),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (picked == null) return;

    selectedDate.value = picked;
    dateController.text = DateFormat('yyyy-MM-dd').format(picked);
    await cargarHistorial();
  }

  void setFilter(String filter) {
    if (!filters.contains(filter)) return;
    selectedFilter.value = filter;
  }

  List<VisitaHistorial> get filteredVisits {
    final query = searchText.value.toLowerCase();
    return visitas.where((visita) {
      final matchesFilter = switch (selectedFilter.value) {
        'efectivas' => visita.efectiva && !visita.pendienteOffline,
        'no_efectivas' => !visita.efectiva && !visita.pendienteOffline,
        'pendientes' => visita.pendienteOffline,
        _ => true,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;

      return visita.clienteNombre.toLowerCase().contains(query) ||
          visita.resultado.toLowerCase().contains(query) ||
          (visita.rutaNombre ?? '').toLowerCase().contains(query) ||
          (visita.zonaNombre ?? '').toLowerCase().contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get pendientesOffline => registrosOffline
      .where((record) => (record['status'] ?? '').toString() == 'pending')
      .toList();

  List<Map<String, dynamic>> get sincronizadosRecientes => registrosOffline
      .where((record) => (record['status'] ?? '').toString() == 'synced')
      .take(20)
      .toList();

  int get total => visitas.length;
  int get efectivas =>
      visitas.where((e) => e.efectiva && !e.pendienteOffline).length;
  int get noEfectivas =>
      visitas.where((e) => !e.efectiva && !e.pendienteOffline).length;
  int get pendientes => visitas.where((e) => e.pendienteOffline).length;

  int pendientesPorTipo(String kind) => pendientesOffline
      .where((record) => (record['kind'] ?? '').toString() == kind)
      .length;

  double get efectividadPorcentaje {
    final sincronizadas = efectivas + noEfectivas;
    if (sincronizadas == 0) return 0;
    return (efectivas / sincronizadas) * 100;
  }

  Future<void> sincronizarPendientes() async {
    final sync = _sync;
    if (sync == null) {
      SafeUi.snackbar(
        'Sincronización',
        'El servicio de sincronización no está disponible.',
      );
      return;
    }

    final enviados = await sync.syncPending();
    if (Get.isRegistered<VisitadorOperativoController>()) {
      await Get.find<VisitadorOperativoController>().refreshAll();
    }
    await cargarHistorial();

    if (enviados > 0) {
      SafeUi.snackbar(
        'Sincronización completada',
        'Se enviaron $enviados registro(s) pendientes.',
      );
    } else {
      SafeUi.snackbar('Sincronización', sync.lastSyncMessage.value);
    }
  }

  String tipoRegistro(Map<String, dynamic> record) {
    return switch ((record['kind'] ?? '').toString()) {
      'visita' => 'Visita médica',
      'tracking' => 'Ubicación GPS',
      'jornada_inicio' => 'Inicio de jornada',
      'jornada_cierre' => 'Cierre de jornada',
      _ => 'Registro offline',
    };
  }

  String detalleRegistro(Map<String, dynamic> record) {
    try {
      final decoded = jsonDecode((record['payload'] ?? '{}').toString());
      if (decoded is! Map) return (record['endpoint'] ?? '').toString();
      final payload = Map<String, dynamic>.from(decoded);
      final kind = (record['kind'] ?? '').toString();

      if (kind == 'visita') {
        final clienteId = _toInt(payload['cliente_id']);
        final detalle = clienteId == null
            ? null
            : _routeDetailsByClient()[clienteId];
        final cliente =
            detalle?['nombre']?.toString() ?? 'Cliente #${clienteId ?? '--'}';
        final resultado = payload['resultado']?.toString().trim();
        return resultado == null || resultado.isEmpty
            ? cliente
            : '$cliente · $resultado';
      }
      if (kind == 'tracking') {
        final lat = payload['latitude'] ?? payload['lat'];
        final lng = payload['longitude'] ?? payload['lng'];
        return lat == null || lng == null
            ? 'Punto GPS pendiente'
            : '$lat, $lng';
      }
      if (kind == 'jornada_inicio') {
        return 'Apertura pendiente de la jornada';
      }
      if (kind == 'jornada_cierre') {
        return 'Cierre pendiente de la jornada';
      }
      return (record['endpoint'] ?? '').toString();
    } catch (_) {
      return (record['endpoint'] ?? '').toString();
    }
  }

  DateTime? fechaRegistro(Map<String, dynamic> record) {
    final status = (record['status'] ?? '').toString();
    if (status == 'synced') {
      return _parseDate(record['synced_at']) ??
          _parseDate(record['created_at']);
    }
    return _parseDate(record['created_at']);
  }

  String? errorRegistro(Map<String, dynamic> record) {
    final value = record['last_error']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  int intentosRegistro(Map<String, dynamic> record) =>
      _toInt(record['attempts']) ?? 0;

  List<VisitaHistorial> _offlineVisitsForDate(
    List<Map<String, dynamic>> records,
    DateTime selected,
  ) {
    final routeDetails = _routeDetailsByClient();
    final result = <VisitaHistorial>[];

    for (final record in records) {
      try {
        final decoded = jsonDecode((record['payload'] ?? '{}').toString());
        if (decoded is! Map) continue;
        final payload = Map<String, dynamic>.from(decoded);
        final fecha =
            _parseDate(payload['fecha_inicio']) ??
            _parseDate(record['created_at']);
        if (fecha == null || !_sameDate(fecha, selected)) continue;

        final clienteId = _toInt(payload['cliente_id']);
        final detalle = clienteId == null ? null : routeDetails[clienteId];
        result.add(
          VisitaHistorial.fromOffline(
            record: record,
            payload: payload,
            clienteNombre: detalle?['nombre']?.toString(),
            clienteDireccion: detalle?['direccion']?.toString(),
          ),
        );
      } catch (_) {
        // Un payload local inválido no debe impedir mostrar el resto del historial.
      }
    }
    return result;
  }

  Map<int, Map<String, dynamic>> _routeDetailsByClient() {
    if (!Get.isRegistered<VisitadorOperativoController>()) return {};
    final operativo = Get.find<VisitadorOperativoController>();
    final result = <int, Map<String, dynamic>>{};
    for (final detalle in operativo.detallesRuta) {
      final clienteRaw = detalle['cliente'];
      final cliente = clienteRaw is Map
          ? Map<String, dynamic>.from(clienteRaw)
          : Map<String, dynamic>.from(detalle);
      final id = _toInt(cliente['cliente_id'] ?? detalle['cliente_id']);
      if (id == null) continue;
      result[id] = {
        'nombre': cliente['cliente_nombre'] ?? 'Cliente #$id',
        'direccion': cliente['cliente_dir'],
      };
    }
    return result;
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString().replaceFirst(' ', 'T'));
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  @override
  void onClose() {
    dateController.dispose();
    searchController.dispose();
    super.onClose();
  }
}
