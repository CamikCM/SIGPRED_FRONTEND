import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../app/services/auth_service.dart';
import '../../../../app/utils/safe_ui.dart';
import '../../../data/models/location_results.dart';
import '../../../data/providers/location_provider.dart';

class TrackingUserOption {
  const TrackingUserOption({
    required this.id,
    required this.name,
    required this.role,
  });

  final int id;
  final String name;
  final String role;

  factory TrackingUserOption.fromMap(Map<String, dynamic> map) {
    final rawId = map['id'];
    final id = rawId is int
        ? rawId
        : rawId is num
        ? rawId.toInt()
        : int.tryParse(rawId?.toString() ?? '') ?? 0;

    return TrackingUserOption(
      id: id,
      name: (map['name'] ?? 'Visitador $id').toString(),
      role: (map['role'] ?? '').toString(),
    );
  }
}

class HistoryTabController extends GetxController {
  final LocationProvider _provider = LocationProvider();

  final isLoading = false.obs;
  final isLoadingUsers = false.obs;

  final userLocations = <LocationResult>[].obs;
  final availableUsers = <TrackingUserOption>[].obs;

  final selectedUserId = Rxn<int>();
  final selectedUserName = ''.obs;

  final selectedDate = Rxn<DateTime>();
  final dateController = TextEditingController();

  final mapStyles = {
    'Claro': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'Gris': 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
    'Oscuro': 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
    'Satélite':
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  };

  final currentMap = 'Claro'.obs;

  AuthService get _auth => Get.find<AuthService>();

  bool get isSupervisor {
    final role = _auth.currentUser.value?.roleLabel ?? '';
    return role.toLowerCase().contains('supervisor');
  }

  String get selectedUserLabel {
    final name = selectedUserName.value.trim();
    if (name.isNotEmpty) return name;

    final id = selectedUserId.value;
    if (id != null) return 'Visitador $id';

    return 'Selecciona un visitador';
  }

  @override
  void onInit() {
    super.onInit();

    final now = DateTime.now();
    selectedDate.value = now;
    dateController.text = DateFormat('yyyy-MM-dd').format(now);

    final currentUser = _auth.currentUser.value;
    if (currentUser != null && !isSupervisor) {
      selectedUserId.value = currentUser.id;
      selectedUserName.value = currentUser.name;
    }
  }

  Future<void> initialize() async {
    final currentUser = _auth.currentUser.value;
    if (currentUser == null) {
      SafeUi.snackbar('Historial', 'Usuario no autenticado');
      return;
    }

    if (isSupervisor) {
      await loadTrackableUsers();
    } else {
      selectedUserId.value = currentUser.id;
      selectedUserName.value = currentUser.name;
    }

    await fetchUserLocations();
  }

  Future<void> loadTrackableUsers() async {
    try {
      isLoadingUsers.value = true;

      final currentUser = _auth.currentUser.value;
      if (currentUser == null) {
        throw Exception('Usuario no autenticado');
      }

      final rawUsers = await _provider.getTrackableUsers();

      final users = rawUsers
          .map(TrackingUserOption.fromMap)
          .where((item) => item.id > 0 && item.id != currentUser.id)
          .toList();

      availableUsers.assignAll(users);

      if (users.isEmpty) {
        selectedUserId.value = null;
        selectedUserName.value = '';
        userLocations.clear();
        debugPrint('ℹ️ Supervisor sin visitadores con ubicación disponible.');
        return;
      }

      final currentSelection = selectedUserId.value;
      TrackingUserOption? selected;

      if (currentSelection != null) {
        for (final item in users) {
          if (item.id == currentSelection) {
            selected = item;
            break;
          }
        }
      }

      selected ??= users.first;
      selectedUserId.value = selected.id;
      selectedUserName.value = selected.name;

      debugPrint(
        '👤 Visitador seleccionado para historial: '
        '${selected.id} - ${selected.name}',
      );
    } catch (e) {
      debugPrint('🚨 Error cargando visitadores del supervisor: $e');
      availableUsers.clear();
      selectedUserId.value = null;
      selectedUserName.value = '';
      userLocations.clear();
      SafeUi.snackbar(
        'Historial',
        'No se pudo cargar el equipo del supervisor',
      );
    } finally {
      isLoadingUsers.value = false;
    }
  }

  Future<void> selectUser(int userId) async {
    TrackingUserOption? selected;

    for (final item in availableUsers) {
      if (item.id == userId) {
        selected = item;
        break;
      }
    }

    if (selected == null) {
      SafeUi.snackbar('Historial', 'Visitador no disponible');
      return;
    }

    selectedUserId.value = selected.id;
    selectedUserName.value = selected.name;
    userLocations.clear();

    debugPrint(
      '👤 Cambiando historial a visitador '
      '${selected.id} - ${selected.name}',
    );

    await fetchUserLocations();
  }

  Future<void> pickDate(BuildContext context) async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.value ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );

    if (picked != null) {
      selectedDate.value = picked;
      dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      await fetchUserLocations();
    }
  }

  Future<void> fetchUserLocations() async {
    try {
      isLoading.value = true;

      final currentUser = _auth.currentUser.value;
      if (currentUser == null) {
        throw Exception('Usuario no autenticado');
      }

      final userId = isSupervisor ? selectedUserId.value : currentUser.id;

      if (userId == null) {
        userLocations.clear();
        debugPrint(
          'ℹ️ No hay visitador seleccionado para consultar historial.',
        );
        return;
      }

      debugPrint(
        '🔎 Buscando historial para userId=$userId '
        'fecha=${dateController.text} '
        '(autenticado=${currentUser.id})',
      );

      final result = await _provider.getUserLocations(
        userId: userId,
        perPage: 500,
        from: dateController.text.isNotEmpty ? dateController.text : null,
        to: dateController.text.isNotEmpty ? dateController.text : null,
      );

      userLocations.assignAll(result.data);

      debugPrint(
        '✅ Puntos del recorrido cargados: ${userLocations.length} '
        'para userId=$userId',
      );
    } catch (e) {
      userLocations.clear();
      debugPrint('🚨 Error en fetchUserLocations: $e');
      SafeUi.snackbar('Historial', 'No se pudo cargar el recorrido');
    } finally {
      isLoading.value = false;
    }
  }

  void changeMapStyle(String style) {
    currentMap.value = style;
  }

  String get pointCountText => '${userLocations.length} puntos';

  String get distanceText {
    final meters = totalDistanceMeters;
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String get timeRangeText {
    if (userLocations.isEmpty) return '--';

    final first = userLocations.first.capturedAt;
    final last = userLocations.last.capturedAt;
    final formatter = DateFormat('HH:mm');

    return '${formatter.format(first)} - ${formatter.format(last)}';
  }

  double get avgAccuracy {
    final values = userLocations
        .map((e) => e.accuracy)
        .whereType<double>()
        .where((e) => e.isFinite && e > 0)
        .toList();

    if (values.isEmpty) return 0;

    return values.reduce((a, b) => a + b) / values.length;
  }

  double get totalDistanceMeters {
    if (userLocations.length < 2) return 0;

    double total = 0;

    for (var i = 1; i < userLocations.length; i++) {
      final prev = userLocations[i - 1];
      final curr = userLocations[i];

      total += _haversineMeters(
        prev.latitude,
        prev.longitude,
        curr.latitude,
        curr.longitude,
      );
    }

    return total;
  }

  double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const radius = 6371000.0;

    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return radius * c;
  }

  double _degToRad(double deg) => deg * math.pi / 180;

  @override
  void onClose() {
    dateController.dispose();
    super.onClose();
  }
}
