import 'package:get/get.dart';

import '../../../data/providers/auth_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../services/auth_service.dart';
import '../../../utils/safe_ui.dart';

class LogoutController extends GetxController {
  final isLoading = false.obs;

  final AuthProvider _authProvider = Get.find<AuthProvider>();
  final AuthService _auth = Get.find<AuthService>();

  /// Cierra la sesión de forma segura.
  ///
  /// Regla importante para la app móvil:
  /// - Aunque el backend responda 401 o falle la conexión, se elimina la sesión local.
  /// - Así se evita que el usuario quede atrapado dentro de la app.
  /// - No usa Get.snackbar directamente para evitar el error "No Overlay widget found".
  Future<void> doLogout() async {
    if (isLoading.value) return;

    isLoading.value = true;
    String message = 'Sesión cerrada.';

    try {
      final currentToken = _auth.token.value;

      if (currentToken.isNotEmpty) {
        final data = await _authProvider.logout(token: currentToken);
        message = (data['message'] ?? message).toString();
      }
    } catch (e) {
      // Si el token ya venció, si Laravel responde 401 o si no hay conexión,
      // igual se limpia la sesión local para permitir volver al login.
      message = 'Sesión local cerrada.';
    } finally {
      await _auth.clearSession();
      isLoading.value = false;
    }

    SafeUi.snackbar('Sesión', message);
    Get.offAllNamed(Routes.login);
  }
}
