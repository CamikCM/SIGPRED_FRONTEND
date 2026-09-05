# SigmaCity v17 - Corrección de dependencia Flutter Map

Se corrigió el conflicto de dependencias entre `flutter_map ^7.0.2` y `flutter_map_cancellable_tile_provider`.

La versión compatible es:

```yaml
flutter_map: ^7.0.2
flutter_map_cancellable_tile_provider: ^3.0.2
```

No se actualizó `flutter_map` a 8.x para evitar romper la API existente del proyecto.

Comandos:

```bash
flutter clean
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```
