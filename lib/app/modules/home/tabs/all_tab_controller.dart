import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../../data/providers/location_provider.dart';
import '../../../data/models/userlastlocation.dart';
import '../../../../app/utils/safe_ui.dart';

class AllTabController extends GetxController {
  final LocationProvider _provider = LocationProvider();

  var isLoading = false.obs;
  var usersLocations = <UserLastLocation>[].obs;

  /// Estilos de mapa disponibles
  final mapStyles = {
    "OSM": 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    "Carto Dark":
        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
    "Carto Light":
        'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
    "Esri Sat":
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  };

  var currentMap = "OSM".obs;

  @override
  void onInit() {
    super.onInit();
    fetchLocations();
  }

  /// 📡 Obtener las últimas ubicaciones
  Future<void> fetchLocations() async {
    try {
      isLoading.value = true;
      print("🔄 Cargando últimas ubicaciones...");

      final result = await _provider.getLastLocations();
      usersLocations.assignAll(result);

      print("✅ Ubicaciones cargadas: ${usersLocations.length}");
    } catch (e) {
      print("🚨 Error al obtener ubicaciones: $e");
      SafeUi.snackbar("Error", "No se pudieron cargar las ubicaciones");
    } finally {
      isLoading.value = false;
    }
  }

  /// 📲 Método para pull-to-refresh
  Future<void> refreshLocations() async {
    await fetchLocations();
  }

  /// Cambiar estilo de mapa
  void changeMapStyle(String style) {
    currentMap.value = style;
  }
}
