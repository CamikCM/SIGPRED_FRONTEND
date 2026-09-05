# SIGPRED v20 - Interfaz Administrador

Cambios realizados:

- Se incorporó el logo oficial de Biofarma S.A. / Línea Sigma Corp. en el panel web.
- Se actualizó el panel administrativo con estética SIGPRED.
- Se rediseñó el Dashboard del Administrador con datos de demostración.
- Se rediseñó Gestión de Clientes con filtros, tarjetas, tabla y paginación visual.
- El panel mantiene la separación por roles:
  - Administrador: panel web administrativo.
  - Supervisor: panel web y app móvil.
  - Visitador médico: app móvil.

Comando de prueba web:

```bash
flutter clean
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

Backend:

```bash
php artisan serve
```

Nota: algunos datos del panel administrativo son ficticios para mostrar el modelo visual de interfaz mientras se completan endpoints del backend.
