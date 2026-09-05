# SigmaCity v16 - Map Provider Fix

Se agregó `flutter_map_cancellable_tile_provider` y se configuró `CancellableNetworkTileProvider()` en los mapas para Flutter Web.

El mensaje de flutter_map era una recomendación de rendimiento, pero al no usarse el proveedor recomendado algunos navegadores pueden dejar el mapa gris o cargar tiles de forma inestable.

## Ejecutar panel web

```bash
flutter clean
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

Si Chrome/Brave muestra `webGLVersion is -1`, activar aceleración por hardware en el navegador o probar con Google Chrome estable.
