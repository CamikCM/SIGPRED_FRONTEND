import 'package:get/get.dart';
import 'home_controller.dart';
import '../auth/logout/logout_controller.dart';
import 'supervisor/supervisor_dashboard_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(() => HomeController());

    Get.lazyPut<LogoutController>(() => LogoutController());
    Get.lazyPut<SupervisorDashboardController>(
      () => SupervisorDashboardController(),
      fenix: true,
    );
  }
}
