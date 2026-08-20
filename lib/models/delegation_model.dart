class DelegationPerson {
  DelegationPerson({required this.id, required this.name, this.email});

  final int id;
  final String name;
  final String? email;

  factory DelegationPerson.fromJson(Map<String, dynamic> json) {
    return DelegationPerson(
      id: _asInt(json['id']),
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
    );
  }
}

class DelegationModel {
  DelegationModel({
    required this.id,
    this.admin,
    this.delegatedUser,
    this.startDate,
    this.endDate,
    required this.status,
    required this.isCurrentlyActive,
  });

  final int id;
  final DelegationPerson? admin;
  final DelegationPerson? delegatedUser;
  final String? startDate;
  final String? endDate;
  final String status;
  final bool isCurrentlyActive;

  factory DelegationModel.fromJson(Map<String, dynamic> json) {
    final admin = json['admin'];
    final delegated = json['delegated_user'];
    return DelegationModel(
      id: _asInt(json['id']),
      admin: admin is Map<String, dynamic>
          ? DelegationPerson.fromJson(admin)
          : null,
      delegatedUser: delegated is Map<String, dynamic>
          ? DelegationPerson.fromJson(delegated)
          : null,
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      status: json['status'] as String? ?? '',
      isCurrentlyActive: json['is_currently_active'] == true,
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.parse('$value');
}
