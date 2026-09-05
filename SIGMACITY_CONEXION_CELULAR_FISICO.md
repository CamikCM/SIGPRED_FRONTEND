# Conexión con Laravel desde celular físico

Si se prueba en un celular real, NO usar `127.0.0.1` ni `localhost`, porque eso apunta al propio teléfono.

## 1. En Laravel

```bash
php artisan serve --host=0.0.0.0 --port=8000
```

## 2. Obtener IP de la laptop

```bash
hostname -I
```

Ejemplo: `192.168.1.20`

## 3. Ejecutar Flutter con la URL correcta

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000/api
```

El teléfono y la laptop deben estar conectados a la misma red WiFi.

## 4. Verificar desde el navegador del teléfono

Abrir:

```text
http://192.168.1.20:8000
```

Debe responder la API de SigmaCity.
