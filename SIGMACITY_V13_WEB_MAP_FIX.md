# SigmaCity Tracking - v13 Web Map Fix

Cambios aplicados:

- Se corrigió `SafeUi.snackbar` para que no use `Get.snackbar` directamente.
- Se reemplazó el uso directo de `Get.snackbar` en el tracking móvil.
- El error `No Overlay widget found` ya no debe interrumpir la carga del panel web ni el mapa.
- El aviso de `flutter_map_cancellable_tile_provider` es solo una recomendación de rendimiento para web; no impide visualizar el mapa.

Comandos para probar web:

```bash
flutter clean
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

Comandos para probar móvil con adb reverse:

```bash
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```
