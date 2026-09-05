# SigmaCity Tracking Mobile v9

## Cambios principales

- Interfaz móvil modernizada con identidad SigmaCity: fucsia/magenta, tarjetas, métricas y mapas más limpios.
- Home muestra estado operativo, precisión, puntos enviados y recorrido en vivo.
- Historial ahora está preparado para dibujar el camino recorrido completo con polilínea.
- Historial evita errores de `Infinity or NaN toInt` cuando solo existe un punto.
- Todos muestra últimas ubicaciones de usuarios para supervisión móvil.
- URL configurable con `--dart-define=API_BASE_URL=...`.

## Importante para historial completo

Para que Historial muestre el camino completo, Laravel debe tener activo:

GET /api/tracking/locations?user_id=4&from=2026-05-30&to=2026-05-30

Si ese endpoint no existe, la app solo podrá mostrar `/api/tracking/me/last-location`, es decir, el último punto.

## Uso con adb reverse

```bash
adb reverse tcp:8000 tcp:8000
php artisan serve
flutter clean
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

## Uso con emulador Android

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```
