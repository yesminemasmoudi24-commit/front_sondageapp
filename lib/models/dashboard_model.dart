class DashboardModel {
  DashboardModel({
    required this.employees,
    required this.surveys,
    required this.delegations,
    required this.participation,
    required this.recentSurveys,
    required this.recentDelegations,
  });

  final Map<String, dynamic> employees;
  final Map<String, dynamic> surveys;
  final Map<String, dynamic> delegations;
  final Map<String, dynamic> participation;
  final List<Map<String, dynamic>> recentSurveys;
  final List<Map<String, dynamic>> recentDelegations;

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> listOf(dynamic raw) {
      if (raw is! List) return [];
      return raw.whereType<Map<String, dynamic>>().toList();
    }

    Map<String, dynamic> mapOf(dynamic raw) {
      if (raw is Map<String, dynamic>) return raw;
      return {};
    }

    return DashboardModel(
      employees: mapOf(json['employees']),
      surveys: mapOf(json['surveys']),
      delegations: mapOf(json['delegations']),
      participation: mapOf(json['participation']),
      recentSurveys: listOf(json['recent_surveys']),
      recentDelegations: listOf(json['recent_delegations']),
    );
  }
}
