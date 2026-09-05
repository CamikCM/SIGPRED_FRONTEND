class User {
  final int id;
  final String name;
  final String email;
  final String? telefono;
  final String? device;
  final int? rolId;
  final String? rolNombre;
  final int? empresaId;
  final String? empresaNombre;
  final int? supervisorId;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.telefono,
    this.device,
    this.rolId,
    this.rolNombre,
    this.empresaId,
    this.empresaNombre,
    this.supervisorId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final rol = json['rol'];
    final empresa = json['empresa'];

    return User(
      id: _toInt(json['id'] ?? json['usu_id']) ?? 0,
      name: (json['nombre'] ?? json['name'] ?? json['usu_nombre'] ?? '')
          .toString(),
      email: (json['email'] ?? json['usu_email'] ?? '').toString(),
      telefono: (json['telefono'] ?? json['usu_telefono'])?.toString(),
      device: (json['device'] ?? json['usu_device'])?.toString(),
      rolId: rol is Map
          ? _toInt(rol['id'] ?? rol['rol_id'])
          : _toInt(json['rol_id']),
      rolNombre: rol is Map
          ? (rol['nombre'] ?? rol['rol_nombre'])?.toString()
          : json['rol_nombre']?.toString(),
      empresaId: empresa is Map
          ? _toInt(empresa['id'] ?? empresa['emp_id'])
          : _toInt(json['empresa_id'] ?? json['emp_id']),
      empresaNombre: empresa is Map
          ? (empresa['nombre'] ?? empresa['emp_nombre'])?.toString()
          : (json['empresa_nombre'] ?? json['emp_nombre'])?.toString(),
      supervisorId: _toInt(json['supervisor_id']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': name,
    'name': name,
    'email': email,
    'telefono': telefono,
    'device': device,
    'rol_id': rolId,
    'rol_nombre': rolNombre,
    'empresa_id': empresaId,
    'empresa_nombre': empresaNombre,
    'supervisor_id': supervisorId,
  };

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String get normalizedRole => (rolNombre ?? '').trim().toLowerCase();

  bool get isVisitador {
    return rolId == 3 ||
        normalizedRole.contains('visitador') ||
        normalizedRole.contains('médico') ||
        normalizedRole.contains('medico');
  }

  bool get isSupervisor {
    return rolId == 2 || normalizedRole.contains('supervisor');
  }

  bool get isAdministrador {
    return rolId == 1 ||
        normalizedRole.contains('administrador') ||
        normalizedRole.contains('admin');
  }

  String get roleLabel {
    if ((rolNombre ?? '').trim().isNotEmpty) return rolNombre!.trim();
    if (isVisitador) return 'Visitador médico';
    if (isSupervisor) return 'Supervisor';
    if (isAdministrador) return 'Administrador';
    return 'Sin rol';
  }
}
