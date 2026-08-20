class SurveyResultModel {
  SurveyResultModel({
    required this.surveyId,
    required this.title,
    required this.isAnonymous,
    required this.participants,
    required this.targetCount,
    required this.participationRate,
    required this.questions,
  });

  final int surveyId;
  final String title;
  final bool isAnonymous;
  final int participants;
  final int targetCount;
  final num participationRate;
  final List<Map<String, dynamic>> questions;

  factory SurveyResultModel.fromJson(Map<String, dynamic> json) {
    final questions = json['questions'];
    return SurveyResultModel(
      surveyId: json['survey_id'] is num
          ? (json['survey_id'] as num).toInt()
          : int.tryParse('${json['survey_id']}') ?? 0,
      title: json['title'] as String? ?? '',
      isAnonymous: json['is_anonymous'] == true,
      participants: json['participants'] is num
          ? (json['participants'] as num).toInt()
          : int.tryParse('${json['participants']}') ?? 0,
      targetCount: json['target_count'] is num
          ? (json['target_count'] as num).toInt()
          : int.tryParse('${json['target_count']}') ?? 0,
      participationRate: json['participation_rate'] as num? ?? 0,
      questions: questions is List
          ? questions.whereType<Map<String, dynamic>>().toList()
          : const [],
    );
  }
}
