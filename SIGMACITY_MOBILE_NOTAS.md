# SigmaCity Tracking - App móvil actualizada

Esta versión fue ajustada para funcionar con el backend Laravel actual:

- `POST /api/login`
- `POST /api/register` con fallback automático a `POST /api/register-dev`
- `POST /api/tracking/locations`
- `POST /api/tracking/locations/bulk`
- `GET /api/tracking/me/last-location`
- `GET /api/tracking/last-locations`

## Configuración de URL

Archivo:

```text
lib/app/utils/env.dart
```

Para emulador Android:

```dart
static const String apiBaseUrl = 'http://10.0.2.2:8000/api';
```

Para celular físico, reemplazar por la IP local de la laptop:

```dart
static const String apiBaseUrl = 'http://192.168.1.20:8000/api';
```

Y levantar Laravel con:

```bash
php artisan serve --host=0.0.0.0 --port=8000
```

## Comandos recomendados

```bash
flutter clean
flutter pub get
flutter run
```

## Prueba inicial

Usar el usuario demo:

```text
visitador@sigma.local
admin123
```

Luego iniciar tracking y verificar en MongoDB:

```js
use sigmacity_tracking
db.tracking_locations.find().pretty()
db.last_locations.find().pretty()
```
