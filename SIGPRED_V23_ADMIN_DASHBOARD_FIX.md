# SIGPRED v23 - Corrección Dashboard Administrador

Cambios aplicados:

- Se corrigió el dashboard del Administrador para que ya no quede en blanco.
- Se agregó contenido visual con datos ficticios/demostrativos:
  - Tarjetas KPI.
  - Resumen operativo semanal.
  - Estado del sistema PostgreSQL, MongoDB y Laravel API.
  - Accesos rápidos a módulos administrativos.
  - Tabla de últimos clientes registrados.
- Se mantiene la separación de menús por rol:
  - Administrador: Dashboard, Clientes, Zonas, Rutas, Operaciones, Reportes, Configuración.
  - Supervisor: Dashboard, Zonas, Clientes, Rutas, Visitas, Tracking, Reportes, Configuración.
- Se cambió el nombre visible de la app móvil Android de `SigmaCity Tracking` a `SIGPRED`.
- Se mantiene sin opción de crear cuenta en el login móvil/web. La creación de usuarios corresponde al Administrador desde el panel web.

Comandos de prueba web:

```bash
flutter clean
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

Comandos de prueba móvil con adb reverse:

```bash
adb reverse tcp:8000 tcp:8000
flutter clean
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```
