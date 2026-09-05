# SigmaCity Tracking - Panel web integrado en Flutter

Esta versión mantiene **app móvil y panel web dentro del mismo proyecto Flutter**, separados por carpetas y rutas.

## Arquitectura de acceso

- Visitador médico → App móvil.
- Supervisor → App móvil + Panel web.
- Administrador → Panel web.

## Carpetas nuevas

```text
lib/app/modules/web_panel/
├── layout/             # Shell web, sidebar y topbar
├── admin/              # Dashboard del administrador
├── supervisor/         # Dashboard del supervisor
├── shared/             # Clientes, rutas, visitas, tracking y reportes
└── access_blocked/     # Bloqueo web para visitador
```

## Rutas web agregadas

```text
/web/admin/dashboard
/web/supervisor/dashboard
/web/usuarios
/web/clientes
/web/rutas
/web/visitas
/web/tracking
/web/reportes
/web/access-blocked
```

## Cómo ejecutar móvil con adb reverse

```bash
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

## Cómo ejecutar panel web

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

## Backend Laravel

```bash
php artisan serve
```

## Prueba por roles

```text
admin@sigma.local / admin123       → Panel web administrador
supervisor@sigma.local / admin123  → Panel web supervisor
visitador@sigma.local / admin123   → En web queda bloqueado, en móvil entra al home operativo
```
