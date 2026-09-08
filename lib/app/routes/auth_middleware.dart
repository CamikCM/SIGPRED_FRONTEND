import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../services/auth_service.dart';
import 'app_routes.dart';

class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (!Get.isRegistered<AuthService>()) {
      return const RouteSettings(name: Routes.login);
    }

    final auth = Get.find<AuthService>();

    if (auth.token.value.isEmpty || auth.currentUser.value == null) {
      return const RouteSettings(name: Routes.login);
    }

    return null;
  }
}
