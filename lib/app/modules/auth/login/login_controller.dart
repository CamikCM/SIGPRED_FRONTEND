import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../routes/app_routes.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../services/auth_service.dart';
import '../../../data/models/user.dart';
import '../../../utils/safe_ui.dart';

class LoginController extends GetxController {
  final formkey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  final isLoading = false.obs;
  final hidePassword = true.obs;

  final AuthProvider _authProvider = Get.find<AuthProvider>();
  final AuthService _auth = Get.find<AuthService>();

  @override
  void onClose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.onClose();
  }

  Future<void> onLoginPressed() async {
    if (!(formkey.currentState?.validate() ?? false)) {
      SafeUi.snackbar('Validación', 'Completa los campos correctamente');
      return;
    }

    final email = emailCtrl.text.trim();
    final password = passCtrl.text;

    isLoading.value = true;
    try {
      // 🔐 Llamamos al provider directamente
      final data = await _authProvider.login(email: email, password: password);

      // 📦 Parseamos los datos aquí en el controller
      final message = (data['message'] ?? 'Login Correcto').toString();
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      final token = data['token'].toString();

      // 💾 Guardamos sesión
      await _auth.saveSession(user, token);

      SafeUi.snackbar('Bienvenido', message);

      _redirectByRole(user);
    } catch (e) {
      SafeUi.snackbar('No se pudo iniciar sesión', _friendlyLoginError(e));
    } finally {
      isLoading.value = false;
    }
  }

  String _friendlyLoginError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final value = raw.toLowerCase();

    if (value.contains('401') ||
        value.contains('unauthorized') ||
        value.contains('credencial') ||
        value.contains('contraseña') ||
        value.contains('password')) {
      return 'Correo o contraseña incorrectos. Verifica los datos e intenta nuevamente.';
    }

    if (value.contains('inactiv') || value.contains('desactiv')) {
      return 'Tu cuenta no está activa. Comunícate con el administrador del sistema.';
    }

    if (value.contains('socketexception') ||
        value.contains('connection') ||
        value.contains('network') ||
        value.contains('dioexception') ||
        value.contains('timed out') ||
        value.contains('timeout')) {
      return 'No se pudo conectar con SIGPRED. Revisa la conexión y vuelve a intentarlo.';
    }

    return 'No fue posible validar el acceso. Intenta nuevamente o comunícate con el administrador.';
  }

  void _redirectByRole(User user) {
    if (kIsWeb) {
      if (user.isAdministrador) {
        Get.offAllNamed(Routes.webAdminDashboard);
        return;
      }

      if (user.isSupervisor) {
        Get.offAllNamed(Routes.webSupervisorDashboard);
        return;
      }

      if (user.isVisitador) {
        Get.offAllNamed(Routes.webAccessBlocked);
        return;
      }
    } else {
      if (user.isVisitador) {
        Get.offAllNamed(Routes.home);
        return;
      }

      if (user.isSupervisor) {
        Get.offAllNamed(Routes.supervisorHome);
        return;
      }

      if (user.isAdministrador) {
        Get.offAllNamed(Routes.adminBlocked);
        return;
      }
    }

    SafeUi.snackbar(
      'Rol no reconocido',
      'No se pudo identificar el perfil del usuario.',
    );
  }
}
