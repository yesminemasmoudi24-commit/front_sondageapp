class QuestionOption {
  QuestionOption({
    required this.id,
    required this.optionText,
    required this.order,
  });

  final int id;
  final String optionText;
  final int order;

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      id: _asInt(json['id']),
      optionText: json['option_text'] as String? ?? '',
      order: json['order'] == null ? 0 : _asInt(json['order']),
    );
  }
}

class QuestionModel {
  QuestionModel({
    required this.id,
    required this.surveyId,
    required this.content,
    required this.type,
    required this.order,
    this.options = const [],
  });

  final int id;
  final int surveyId;
  final String content;
  final String type;
  final int order;
  final List<QuestionOption> options;

  static const types = [
    'single_choice',
    'multiple_choice',
    'yes_no',
    'open_answer',
    'satisfaction_scale',
  ];

  bool get requiresOptions =>
      type == 'single_choice' || type == 'multiple_choice';

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    final opts = json['options'];
    return QuestionModel(
      id: _asInt(json['id']),
      surveyId: json['survey_id'] == null ? 0 : _asInt(json['survey_id']),
      content: json['content'] as String? ?? '',
      type: json['type'] as String? ?? '',
      order: json['order'] == null ? 0 : _asInt(json['order']),
      options: opts is List
          ? opts
              .whereType<Map<String, dynamic>>()
              .map(QuestionOption.fromJson)
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
