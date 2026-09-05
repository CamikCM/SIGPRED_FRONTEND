# SIGPRED v19 - Interfaz web Supervisor

Versión ajustada para acercarse al mockup del módulo de seguimiento por zona.

## Cambios principales

- Branding actualizado a **SIGPRED**.
- Subtítulo del sistema: **Sistema Inteligente de Gestión y Visita Médica**.
- Sidebar web claro, corporativo y alineado al mockup.
- Topbar web con marca SIGPRED, notificaciones y perfil de usuario.
- Módulo **Tracking / Seguimiento por Zona** rediseñado con:
  - Filtros superiores: Regional, Zona, Supervisor, Fecha.
  - Tarjetas KPI: puntos registrados, distancia recorrida, conexión, equipo en campo y tiempo en campo.
  - Mapa Leaflet funcional.
  - Tabla de registros del día.
  - Resumen de ruta.
  - Estado del equipo en campo.

## Comando de prueba web

```bash
flutter clean
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

## Backend requerido

Mantener Laravel corriendo:

```bash
php artisan serve
```

El módulo consulta:

```http
GET /api/tracking/last-locations
```

## Nota técnica

El mapa web usa Leaflet embebido para evitar el problema del mapa gris en Flutter Web.
La app móvil conserva su propia implementación de mapa.
