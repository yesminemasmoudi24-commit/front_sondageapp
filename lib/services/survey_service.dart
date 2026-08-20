import '../core/api_client.dart';
import '../models/question_model.dart';
import '../models/survey_model.dart';
import '../models/survey_result_model.dart';

class SurveyService {
  SurveyService(this._api);

  final ApiClient _api;

  List<SurveyModel> _parseList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(SurveyModel.fromJson)
        .toList();
  }

  Future<List<SurveyModel>> list() async {
    final res = await _api.get('/surveys', parser: _parseList);
    return res.data ?? [];
  }

  Future<SurveyModel> show(int id) async {
    final res = await _api.get<SurveyModel>(
      '/surveys/$id',
      parser: (raw) => SurveyModel.fromJson(raw as Map<String, dynamic>),
    );
    return res.data!;
  }

  Future<SurveyModel> create(Map<String, dynamic> body) async {
    final res = await _api.post<SurveyModel>(
      '/surveys',
      body: body,
      parser: (raw) => SurveyModel.fromJson(raw as Map<String, dynamic>),
    );
    return res.data!;
  }

  Future<SurveyModel> update(int id, Map<String, dynamic> body) async {
    final res = await _api.put<SurveyModel>(
      '/surveys/$id',
      body: body,
      parser: (raw) => SurveyModel.fromJson(raw as Map<String, dynamic>),
    );
    return res.data!;
  }

  Future<void> delete(int id) async {
    await _api.delete('/surveys/$id');
  }

  Future<SurveyQrCode> generateQr(int id) async {
    final res = await _api.post<SurveyQrCode>(
      '/surveys/$id/generate-qr',
      parser: (raw) => SurveyQrCode.fromJson(raw as Map<String, dynamic>),
    );
    return res.data!;
  }

  Future<QuestionModel> addQuestion(int surveyId, Map<String, dynamic> body) async {
    final res = await _api.post<QuestionModel>(
      '/surveys/$surveyId/questions',
      body: body,
      parser: (raw) => QuestionModel.fromJson(raw as Map<String, dynamic>),
    );
    return res.data!;
  }

  Future<QuestionModel> updateQuestion(int questionId, Map<String, dynamic> body) async {
    final res = await _api.put<QuestionModel>(
      '/questions/$questionId',
      body: body,
      parser: (raw) => QuestionModel.fromJson(raw as Map<String, dynamic>),
    );
    return res.data!;
  }

  Future<void> deleteQuestion(int questionId) async {
    await _api.delete('/questions/$questionId');
  }

  Future<void> submitAnswers(int surveyId, List<Map<String, dynamic>> answers) async {
    await _api.post(
      '/surveys/$surveyId/answers',
      body: {'answers': answers},
    );
  }

  Future<SurveyResultModel> results(int surveyId) async {
    final res = await _api.get<SurveyResultModel>(
      '/surveys/$surveyId/results',
      parser: (raw) => SurveyResultModel.fromJson(raw as Map<String, dynamic>),
    );
    return res.data!;
  }

  Future<List<int>> exportPdf(int surveyId) =>
      _api.getBytes('/surveys/$surveyId/export/pdf');

  Future<List<int>> exportExcel(int surveyId) =>
      _api.getBytes('/surveys/$surveyId/export/excel');
}
