import 'question_model.dart';

class SurveyCreator {
  SurveyCreator({required this.id, required this.name, this.email});

  final int id;
  final String name;
  final String? email;

  factory SurveyCreator.fromJson(Map<String, dynamic> json) {
    return SurveyCreator(
      id: _asInt(json['id']),
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
    );
  }
}

class SurveyQrCode {
  SurveyQrCode({required this.code, required this.link});

  final String code;
  final String link;

  factory SurveyQrCode.fromJson(Map<String, dynamic> json) {
    return SurveyQrCode(
      code: json['code'] as String? ?? '',
      link: json['link'] as String? ?? '',
    );
  }
}

class SurveyEmployee {
  SurveyEmployee({required this.id, this.position, this.name});

  final int id;
  final String? position;
  final String? name;

  factory SurveyEmployee.fromJson(Map<String, dynamic> json) {
    return SurveyEmployee(
      id: _asInt(json['id']),
      position: json['position'] as String?,
      name: json['name'] as String?,
    );
  }
}

class SurveyModel {
  SurveyModel({
    required this.id,
    required this.title,
    this.description,
    this.startDate,
    this.endDate,
    required this.status,
    this.isAnonymous = false,
    this.createdBy,
    this.creator,
    this.qrCode,
    this.questionsCount,
    this.employeesCount,
    this.questions = const [],
    this.employees = const [],
  });

  final int id;
  final String title;
  final String? description;
  final String? startDate;
  final String? endDate;
  final String status;
  final bool isAnonymous;
  final int? createdBy;
  final SurveyCreator? creator;
  final SurveyQrCode? qrCode;
  final int? questionsCount;
  final int? employeesCount;
  final List<QuestionModel> questions;
  final List<SurveyEmployee> employees;

  factory SurveyModel.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'];
    final qr = json['qr_code'];
    final questions = json['questions'];
    final employees = json['employees'];

    return SurveyModel(
      id: _asInt(json['id']),
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      status: json['status'] as String? ?? 'draft',
      isAnonymous: json['is_anonymous'] == true,
      createdBy: json['created_by'] == null ? null : _asInt(json['created_by']),
      creator: creator is Map<String, dynamic>
          ? SurveyCreator.fromJson(creator)
          : null,
      qrCode: qr is Map<String, dynamic> ? SurveyQrCode.fromJson(qr) : null,
      questionsCount: json['questions_count'] == null
          ? null
          : _asInt(json['questions_count']),
      employeesCount: json['employees_count'] == null
          ? null
          : _asInt(json['employees_count']),
      questions: questions is List
          ? questions
              .whereType<Map<String, dynamic>>()
              .map(QuestionModel.fromJson)
              .toList()
          : const [],
      employees: employees is List
          ? employees
              .whereType<Map<String, dynamic>>()
              .map(SurveyEmployee.fromJson)
              .toList()
          : const [],
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.parse('$value');
}
