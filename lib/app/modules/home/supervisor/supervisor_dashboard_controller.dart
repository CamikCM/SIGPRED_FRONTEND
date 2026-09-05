import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/local/local_database.dart';
import '../../../data/providers/supervisor_provider.dart';
import '../../../services/auth_service.dart';
import '../../../utils/safe_ui.dart';

class SupervisorDashboardController extends GetxController {
  final SupervisorProvider _provider = Get.find<SupervisorProvider>();
  final AuthService _auth = Get.find<AuthService>();
  final LocalDatabase _localDb = LocalDatabase.instance;

  final selectedDate = DateTime.now().obs;
  final resumen = Rxn<Map<String, dynamic>>();
  final rutas = <Map<String, dynamic>>[].obs;
  final efectividadZonas = <Map<String, dynamic>>[].obs;

  final isLoading = false.obs;
  final isRefreshing = false.obs;
  final isUsingCache = false.obs;
  final errorMessage = ''.obs;
  final lastUpdated = Rxn<DateTime>();

  String get _cachePrefix {
    final userId = _auth.currentUser.value?.id ?? 0;
    return 'supervisor:$userId';
  }

  String _cacheKey(String suffix) {
    final date = selectedDate.value.toIso8601String().substring(0, 10);
    return '$_cachePrefix:$date:$suffix';
  }

  int get jornadasIniciadas => _toInt(resumen.value?['jornadas_iniciadas']);
  int get rutasPlanificadas => _toInt(resumen.value?['rutas_planificadas']);
  int get visitasRegistradas => _toInt(resumen.value?['visitas_registradas']);
  int get visitasEfectivas => _toInt(resumen.value?['visitas_efectivas']);
  double get efectividad => _toDouble(resumen.value?['efectividad_porcentaje']);

  int get visitasNoEfectivas {
    final value = visitasRegistradas - visitasEfectivas;
    return value < 0 ? 0 : value;
  }

  int get totalPuntosPlanificados => rutas.fold<int>(0, (total, ruta) {
    final detalles = ruta['detalles'];
    return total + (detalles is List ? detalles.length : 0);
  });

  int get puntosPendientes {
    final value = totalPuntosPlanificados - visitasRegistradas;
    return value < 0 ? 0 : value;
  }

  Map<String, dynamic>? get zonaConMenorEfectividad {
    if (efectividadZonas.isEmpty) return null;
    final rows = efectividadZonas.toList()
      ..sort(
        (a, b) => _toDouble(
          a['efectividad_porcentaje'],
        ).compareTo(_toDouble(b['efectividad_porcentaje'])),
      );
    return rows.first;
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load({bool refresh = false}) async {
    if (isLoading.value || isRefreshing.value) return;

    if (refresh) {
      isRefreshing.value = true;
    } else {
      isLoading.value = true;
    }

    errorMessage.value = '';
    isUsingCache.value = false;

    final desde = DateTime(
      selectedDate.value.year,
      selectedDate.value.month,
      1,
    );

    try {
      final responses = await Future.wait<dynamic>([
        _provider.resumenOperativo(selectedDate.value),
        _provider.rutasHoy(selectedDate.value),
        _provider.efectividadPorZona(desde: desde, hasta: selectedDate.value),
      ]);

      resumen.value = Map<String, dynamic>.from(responses[0] as Map);
      rutas.assignAll(
        (responses[1] as List).whereType<Map>().map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );
      efectividadZonas.assignAll(
        (responses[2] as List).whereType<Map>().map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );

      await Future.wait([
        _localDb.saveJson(_cacheKey('resumen'), resumen.value),
        _localDb.saveJson(_cacheKey('rutas'), rutas.toList()),
        _localDb.saveJson(
          _cacheKey('efectividad_zonas'),
          efectividadZonas.toList(),
        ),
      ]);

      lastUpdated.value = DateTime.now();
    } catch (error) {
      await _restoreCache(error);
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  Future<void> _restoreCache(Object error) async {
    final cachedResumen = await _localDb.readJson<dynamic>(
      _cacheKey('resumen'),
    );
    final cachedRutas = await _localDb.readJson<dynamic>(_cacheKey('rutas'));
    final cachedZonas = await _localDb.readJson<dynamic>(
      _cacheKey('efectividad_zonas'),
    );

    if (cachedResumen is Map) {
      resumen.value = Map<String, dynamic>.from(cachedResumen);
    }
    if (cachedRutas is List) {
      rutas.assignAll(
        cachedRutas.whereType<Map>().map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );
    }
    if (cachedZonas is List) {
      efectividadZonas.assignAll(
        cachedZonas.whereType<Map>().map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );
    }

    final hasCache = resumen.value != null || rutas.isNotEmpty;
    isUsingCache.value = hasCache;
    errorMessage.value = _cleanError(error);

    if (!hasCache) {
      SafeUi.snackbar('No se pudo cargar el panel', errorMessage.value);
    }
  }

  Future<void> selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.value,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    selectedDate.value = DateTime(picked.year, picked.month, picked.day);
    await load();
  }

  Future<void> previousDay() async {
    selectedDate.value = selectedDate.value.subtract(const Duration(days: 1));
    await load();
  }

  Future<void> nextDay() async {
    final next = selectedDate.value.add(const Duration(days: 1));
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (next.isAfter(todayOnly)) return;
    selectedDate.value = next;
    await load();
  }

  Future<void> goToday() async {
    final now = DateTime.now();
    selectedDate.value = DateTime(now.year, now.month, now.day);
    await load();
  }

  bool get canGoNext {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return selectedDate.value.isBefore(today);
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
