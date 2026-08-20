class EmployeeBrief {
  EmployeeBrief({
    required this.id,
    this.position,
    this.status,
    this.name,
  });

  final int id;
  final String? position;
  final String? status;
  final String? name;

  factory EmployeeBrief.fromJson(Map<String, dynamic> json) {
    return EmployeeBrief(
      id: json['id'] as int,
      position: json['position'] as String?,
      status: json['status'] as String?,
      name: json['name'] as String?,
    );
  }
}

class UserModel {
  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.canManageSurveys,
    this.employee,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final String status;
  final bool canManageSurveys;
  final EmployeeBrief? employee;

  bool get isAdmin => role == 'admin';
  bool get isDelegated => role == 'delegated_user';
  bool get isEmployee => role == 'employee';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final emp = json['employee'];
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      status: json['status'] as String? ?? '',
      canManageSurveys: json['can_manage_surveys'] == true,
      employee: emp is Map<String, dynamic> ? EmployeeBrief.fromJson(emp) : null,
    );
  }
}
