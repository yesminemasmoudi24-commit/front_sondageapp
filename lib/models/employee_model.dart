class EmployeeUser {
  EmployeeUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final String status;

  factory EmployeeUser.fromJson(Map<String, dynamic> json) {
    return EmployeeUser(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}

class EmployeeModel {
  EmployeeModel({
    required this.id,
    this.position,
    required this.status,
    this.user,
  });

  final int id;
  final String? position;
  final String status;
  final EmployeeUser? user;

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return EmployeeModel(
      id: json['id'] as int,
      position: json['position'] as String?,
      status: json['status'] as String? ?? 'active',
      user: user is Map<String, dynamic> ? EmployeeUser.fromJson(user) : null,
    );
  }
}
