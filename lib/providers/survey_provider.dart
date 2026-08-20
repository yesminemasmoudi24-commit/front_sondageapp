import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../models/survey_model.dart';
import '../services/survey_service.dart';

class SurveyProvider extends ChangeNotifier {
  final List<SurveyModel> _items = [];
  bool loading = false;
  String? error;
  bool _started = false;
  ApiClient? _api;
  Timer? _pollTimer;

  List<SurveyModel> get items => List.unmodifiable(_items);

  SurveyService? get service =>
      _api == null ? null : SurveyService(_api!);

  Future<void> ensureStarted(ApiClient api) async {
    if (_started && identical(_api, api)) return;
    await stop();
    _api = api;
    _started = true;
    await refresh();
    _startPolling();
  }

  Future<void> stop() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _started = false;
    _api = null;
    _items.clear();
    loading = false;
    error = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    final api = _api;
    if (api == null) return;
    final showLoader = _items.isEmpty;
    if (showLoader) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      final list = await SurveyService(api).list();
      final changed = !_sameList(list);
      _items
        ..clear()
        ..addAll(list);
      loading = false;
      error = null;
      if (changed || showLoader) notifyListeners();
    } on ApiException catch (e) {
      error = e.message;
      loading = false;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    }
  }

  void upsert(SurveyModel survey) {
    final index = _items.indexWhere((s) => s.id == survey.id);
    if (index >= 0) {
      _items[index] = survey;
    } else {
      _items.insert(0, survey);
    }
    notifyListeners();
  }

  void removeById(int id) {
    final before = _items.length;
    _items.removeWhere((s) => s.id == id);
    if (_items.length != before) notifyListeners();
  }

  void applyRealtime({
    required String action,
    SurveyModel? survey,
    int? surveyId,
  }) {
    final normalized = action.toLowerCase();
    if (normalized.contains('deleted') || normalized == 'deleted') {
      final id = surveyId ?? survey?.id;
      if (id != null) removeById(id);
      return;
    }
    if (survey != null) {
      upsert(survey);
      return;
    }
    // Action sans payload complet → resync
    refresh();
  }

  bool _sameList(List<SurveyModel> next) {
    if (next.length != _items.length) return false;
    for (var i = 0; i < next.length; i++) {
      if (next[i].id != _items[i].id ||
          next[i].status != _items[i].status ||
          (next[i].questionsCount ?? next[i].questions.length) !=
              (_items[i].questionsCount ?? _items[i].questions.length)) {
        return false;
      }
    }
    return true;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_started) refresh();
    });
  }
}
