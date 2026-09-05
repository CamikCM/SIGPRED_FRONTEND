# SigmaCity Mobile v11 - Logout y registro móvil

Cambios aplicados:

1. Se quitó la opción de crear cuenta desde la app móvil.
   - La ruta `/register` fue retirada de la navegación Flutter.
   - El botón "Crear usuario de prueba" fue eliminado del login.
   - La gestión de usuarios queda reservada al Administrador desde el panel web.

2. Se corrigió el cierre de sesión.
   - `LogoutController` ya no usa `Get.snackbar` directamente.
   - Ahora usa `SafeUi.snackbar`, evitando el error `No Overlay widget found`.
   - Aunque el token esté vencido o Laravel responda 401, la app limpia la sesión local y regresa al login.

3. Se mantiene la arquitectura por roles:
   - Visitador Médico: app móvil.
   - Supervisor: app móvil + web.
   - Administrador: web; bloqueado en app móvil.

Comandos recomendados:

```bash
adb reverse tcp:8000 tcp:8000
flutter clean
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```
