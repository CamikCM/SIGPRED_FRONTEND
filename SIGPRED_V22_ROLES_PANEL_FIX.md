# SIGPRED v22 - Separación de paneles por rol

Cambios aplicados:

- Sidebar del Administrador separado del Supervisor.
- Rutas web separadas por rol:
  - `/web/admin/...`
  - `/web/supervisor/...`
- El Administrador ve: Dashboard, Clientes, Zonas, Rutas, Operaciones, Reportes y Configuración.
- El Supervisor ve: Dashboard, Zonas, Clientes, Rutas, Visitas, Tracking, Reportes y Configuración.
- Se corrigieron accesos rápidos del dashboard administrador.
- Se corrigió el bug de clicks usando navegación web estable (`Get.offNamed`).
- Se conservan datos ficticios en módulos donde faltan endpoints reales.

Comando web:

```bash
flutter clean
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```
