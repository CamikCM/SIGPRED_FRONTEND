import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../lib/app/data/local/local_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Permite probar sqflite en Linux durante `flutter test`, sin necesitar
  // un emulador Android ni modificar la base SQLite real del teléfono.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final localDb = LocalDatabase.instance;

  setUp(() async {
    await localDb.clearAllOfflineData();
  });

  tearDown(() async {
    await localDb.clearAllOfflineData();
  });

  group('SIGPRED SQLite offline', () {
    test('inserta registro pendiente y conserva correctamente el payload',
        () async {
      final id = await localDb.insertOfflineRecord(
        kind: 'visita',
        method: 'post',
        endpoint: 'visitas',
        payload: {
          'cliente_id': 25,
          'efectiva': true,
          'resultado': 'Pedido generado',
        },
      );

      expect(id, greaterThan(0));
      expect(await localDb.pendingCount(), 1);

      final rows = await localDb.pendingRecords();
      expect(rows, hasLength(1));

      final row = rows.single;

      expect(row['kind'], 'visita');
      expect(row['method'], 'POST');
      expect(row['endpoint'], '/visitas');
      expect(row['status'], 'pending');
      expect(row['attempts'], 0);
      expect((row['uuid'] ?? '').toString(), isNotEmpty);

      final payload = jsonDecode(row['payload'].toString());
      expect(payload['cliente_id'], 25);
      expect(payload['efectiva'], true);
      expect(payload['resultado'], 'Pedido generado');
    });

    test('pendingCount cuenta únicamente registros pendientes', () async {
      final firstId = await localDb.insertOfflineRecord(
        kind: 'jornada_inicio',
        method: 'POST',
        endpoint: '/jornadas/iniciar',
        payload: {'ruta_id': 1},
      );

      await localDb.insertOfflineRecord(
        kind: 'tracking',
        method: 'POST',
        endpoint: '/tracking/locations',
        payload: {
          'latitude': -17.3895,
          'longitude': -66.1568,
        },
      );

      expect(await localDb.pendingCount(), 2);

      await localDb.markSynced(firstId);

      expect(await localDb.pendingCount(), 1);
    });

    test('pendingRecords respeta el orden de creación de la cola', () async {
      await localDb.insertOfflineRecord(
        kind: 'jornada_inicio',
        method: 'POST',
        endpoint: '/jornadas/iniciar',
        payload: {'ruta_id': 10},
      );

      await Future<void>.delayed(const Duration(milliseconds: 3));

      await localDb.insertOfflineRecord(
        kind: 'visita',
        method: 'POST',
        endpoint: '/visitas',
        payload: {'cliente_id': 20},
      );

      await Future<void>.delayed(const Duration(milliseconds: 3));

      await localDb.insertOfflineRecord(
        kind: 'jornada_cierre',
        method: 'POST',
        endpoint: '/jornadas/cerrar',
        payload: {},
      );

      final rows = await localDb.pendingRecords();

      expect(
        rows.map((row) => row['kind']).toList(),
        ['jornada_inicio', 'visita', 'jornada_cierre'],
      );
    });

    test('markFailed conserva pendiente e incrementa intentos', () async {
      final id = await localDb.insertOfflineRecord(
        kind: 'visita',
        method: 'POST',
        endpoint: '/visitas',
        payload: {'cliente_id': 30},
      );

      await localDb.markFailed(id, Exception('Sin conexión'));
      await localDb.markFailed(id, Exception('Timeout'));

      final rows = await localDb.pendingRecords();
      expect(rows, hasLength(1));

      final row = rows.single;
      expect(row['status'], 'pending');
      expect(row['attempts'], 2);
      expect(row['last_error'].toString(), contains('Timeout'));
      expect(await localDb.pendingCount(), 1);
    });

    test('markSynced retira registro de pendientes y conserva historial',
        () async {
      final id = await localDb.insertOfflineRecord(
        kind: 'tracking',
        method: 'POST',
        endpoint: '/tracking/locations',
        payload: {
          'latitude': -17.3895,
          'longitude': -66.1568,
        },
      );

      await localDb.markFailed(id, Exception('Fallo temporal'));
      await localDb.markSynced(id);

      expect(await localDb.pendingCount(), 0);

      final synced = await localDb.offlineRecords(
        statuses: const ['synced'],
      );

      expect(synced, hasLength(1));
      expect(synced.single['status'], 'synced');
      expect(synced.single['synced_at'], isNotNull);
      expect(synced.single['last_error'], isNull);
      expect(synced.single['attempts'], 1);
    });

    test('recordsByKind filtra correctamente tipo y estado', () async {
      await localDb.insertOfflineRecord(
        kind: 'visita',
        method: 'POST',
        endpoint: '/visitas',
        payload: {'cliente_id': 1},
      );

      final trackingId = await localDb.insertOfflineRecord(
        kind: 'tracking',
        method: 'POST',
        endpoint: '/tracking/locations',
        payload: {
          'latitude': -17.3895,
          'longitude': -66.1568,
        },
      );

      await localDb.markSynced(trackingId);

      final pendingVisits = await localDb.recordsByKind(
        kind: 'visita',
        statuses: const ['pending'],
      );

      final syncedTracking = await localDb.recordsByKind(
        kind: 'tracking',
        statuses: const ['synced'],
      );

      expect(pendingVisits, hasLength(1));
      expect(pendingVisits.single['kind'], 'visita');

      expect(syncedTracking, hasLength(1));
      expect(syncedTracking.single['kind'], 'tracking');
      expect(syncedTracking.single['status'], 'synced');
    });

    test('offlineRecords muestra pendientes antes que sincronizados', () async {
      final syncedId = await localDb.insertOfflineRecord(
        kind: 'tracking',
        method: 'POST',
        endpoint: '/tracking/locations',
        payload: {
          'latitude': -17.3800,
          'longitude': -66.1500,
        },
      );

      await localDb.markSynced(syncedId);

      await Future<void>.delayed(const Duration(milliseconds: 3));

      await localDb.insertOfflineRecord(
        kind: 'visita',
        method: 'POST',
        endpoint: '/visitas',
        payload: {'cliente_id': 99},
      );

      final rows = await localDb.offlineRecords(
        statuses: const ['pending', 'synced'],
      );

      expect(rows, hasLength(2));
      expect(rows.first['status'], 'pending');
      expect(rows.last['status'], 'synced');
    });

    test('cache_items guarda, reemplaza, lee y elimina JSON', () async {
      await localDb.saveJson('ruta_hoy', {
        'ruta_id': 101,
        'ruta_nombre': 'Ruta SQLite PHPUnit',
      });

      final first = await localDb.readJson<Map<String, dynamic>>('ruta_hoy');

      expect(first, isNotNull);
      expect(first!['ruta_id'], 101);

      await localDb.saveJson('ruta_hoy', {
        'ruta_id': 202,
        'ruta_nombre': 'Ruta actualizada',
      });

      final replaced =
          await localDb.readJson<Map<String, dynamic>>('ruta_hoy');

      expect(replaced, isNotNull);
      expect(replaced!['ruta_id'], 202);
      expect(replaced['ruta_nombre'], 'Ruta actualizada');

      await localDb.deleteJson('ruta_hoy');

      final deleted =
          await localDb.readJson<Map<String, dynamic>>('ruta_hoy');

      expect(deleted, isNull);
    });

    test('clearAllOfflineData elimina cola offline y cache local', () async {
      await localDb.insertOfflineRecord(
        kind: 'visita',
        method: 'POST',
        endpoint: '/visitas',
        payload: {'cliente_id': 15},
      );

      await localDb.saveJson('productos', [
        {'producto_id': 1, 'producto_nombre': 'Demo'},
      ]);

      expect(await localDb.pendingCount(), 1);
      expect(
        await localDb.readJson<List<dynamic>>('productos'),
        isNotNull,
      );

      await localDb.clearAllOfflineData();

      expect(await localDb.pendingCount(), 0);
      expect(await localDb.offlineRecords(), isEmpty);
      expect(
        await localDb.readJson<List<dynamic>>('productos'),
        isNull,
      );
    });
  });
}
