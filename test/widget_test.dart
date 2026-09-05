import 'package:flutter_test/flutter_test.dart';
import 'package:tracking_andercode_v2/app/data/models/user.dart';

void main() {
  group('Modelo de usuario SIGPRED', () {
    test('interpreta correctamente el rol de Visitador', () {
      final user = User.fromJson({
        'id': 10,
        'nombre': 'Visitador de prueba',
        'email': 'visitador@sigma.test',
        'rol': {
          'id': 3,
          'nombre': 'Visitador',
        },
        'empresa': {
          'id': 1,
          'nombre': 'Sigma Corp.',
        },
      });

      expect(user.isVisitador, isTrue);
      expect(user.isSupervisor, isFalse);
      expect(user.isAdministrador, isFalse);
      expect(user.empresaId, 1);
    });

    test('interpreta correctamente Supervisor y Administrador', () {
      final supervisor = User.fromJson({
        'usu_id': '20',
        'usu_nombre': 'Supervisor',
        'usu_email': 'supervisor@sigma.test',
        'rol_id': '2',
        'rol_nombre': 'Supervisor',
      });

      final administrador = User.fromJson({
        'usu_id': 30,
        'usu_nombre': 'Administrador',
        'usu_email': 'admin@sigma.test',
        'rol_id': 1,
        'rol_nombre': 'Administrador',
      });

      expect(supervisor.isSupervisor, isTrue);
      expect(administrador.isAdministrador, isTrue);
    });

    test('toJson y fromJson conservan empresa y rol', () {
      final original = User(
        id: 5,
        name: 'Usuario',
        email: 'usuario@sigma.test',
        rolId: 2,
        rolNombre: 'Supervisor',
        empresaId: 1,
        empresaNombre: 'Sigma Corp.',
        supervisorId: 4,
      );

      final restored = User.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.email, original.email);
      expect(restored.rolId, original.rolId);
      expect(restored.rolNombre, original.rolNombre);
      expect(restored.empresaId, original.empresaId);
      expect(restored.empresaNombre, original.empresaNombre);
      expect(restored.supervisorId, original.supervisorId);
    });
  });
}
