import 'package:get/get.dart';
import 'data/providers/auth_provider.dart';
import 'data/providers/location_provider.dart';
import 'data/providers/web_api_provider.dart';
import 'data/providers/visitador_provider.dart';
import 'data/providers/supervisor_provider.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';

class GlobalBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }

    Get.lazyPut<AuthProvider>(() => AuthProvider(), fenix: true);
    Get.lazyPut<LocationProvider>(() => LocationProvider(), fenix: true);
    Get.lazyPut<WebApiProvider>(() => WebApiProvider(), fenix: true);
    Get.lazyPut<VisitadorProvider>(() => VisitadorProvider(), fenix: true);
    Get.lazyPut<SupervisorProvider>(() => SupervisorProvider(), fenix: true);
    if (!Get.isRegistered<SyncService>()) {
      Get.lazyPut<SyncService>(() => SyncService(), fenix: true);
    }
  }
}
