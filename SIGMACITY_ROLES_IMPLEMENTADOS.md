# SigmaCity Tracking - Navegación por roles implementada

Esta versión de la app móvil ya separa la interfaz según el rol recibido desde Laravel en `/api/login`, `/api/register` y `/api/me`.

## Lógica de roles

- **Visitador médico** (`rol_id = 3` o nombre con `visitador`): entra al home móvil operativo.
- **Supervisor** (`rol_id = 2` o nombre con `supervisor`): entra al panel móvil de supervisión.
- **Administrador** (`rol_id = 1` o nombre con `administrador/admin`): queda bloqueado en app móvil y se le indica que ingrese por web.

## Archivos modificados

- `lib/app/data/models/user.dart`
- `lib/app/routes/app_routes.dart`
- `lib/app/routes/app_pages.dart`
- `lib/main.dart`
- `lib/app/modules/auth/login/login_controller.dart`
- `lib/app/modules/auth/register/register_controller.dart`

## Archivos nuevos

- `lib/app/modules/home/role/role_home_view.dart`
- `lib/app/modules/home/visitador/visitador_home_view.dart`
- `lib/app/modules/home/supervisor/supervisor_home_view.dart`
- `lib/app/modules/home/admin/admin_mobile_blocked_view.dart`

## Prueba recomendada con adb reverse

```bash
adb reverse tcp:8000 tcp:8000
flutter clean
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

## Usuarios de prueba

- `visitador@sigma.local` / `admin123` → Visitador médico
- `supervisor@sigma.local` / `admin123` → Supervisor
- `admin@sigma.local` / `admin123` → Bloqueado en app móvil

## Nota de arquitectura

Esto cumple la arquitectura funcional definida:

- Visitador médico → App móvil
- Supervisor → App móvil + Web
- Administrador → Web
