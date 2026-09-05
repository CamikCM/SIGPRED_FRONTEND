# SIGPRED v18 - Corrección de mapa web

Esta versión cambia el mapa del panel web de `flutter_map` a un visor web con Leaflet mediante `HtmlElementView`.

## Motivo
En algunos equipos Linux/Chrome/Brave Flutter Web muestra advertencias como:

```text
WARNING: Falling back to CPU-only rendering. Reason: webGLVersion is -1
```

y el mapa de `flutter_map` puede quedar gris aunque los marcadores sí aparezcan. Esto no es problema del backend ni de MongoDB, sino del renderizado web/tiles.

## Solución aplicada
- El panel web de Tracking usa Leaflet dentro de un iframe local (`HtmlElementView`).
- Los puntos siguen viniendo desde Laravel:

```http
GET /api/tracking/last-locations
```

- Se mantiene `flutter_map` en los módulos móviles porque en Android ya funciona correctamente.
- Se actualizó el nombre del sistema a **SIGPRED**.
- Subtítulo: **Sistema Inteligente de Gestión y Visita Médica**.

## Comandos

Backend:

```bash
php artisan serve
```

Panel web:

```bash
flutter clean
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

App móvil con adb reverse:

```bash
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```
