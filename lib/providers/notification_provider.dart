import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final List<NotificationModel> _items = [];
  bool loading = false;
  String? error;
  bool _started = false;
  ApiClient? _api;
  Timer? _pollTimer;

  List<NotificationModel> get items => List.unmodifiable(_items);

  int get unreadCount => _items.where((n) => !n.isRead).length;

  String get badgeLabel {
    final count = unreadCount;
    if (count <= 0) return '';
    if (count > 99) return '99+';
    return '$count';
  }

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

  void addFromRealtime(NotificationModel notification) {
    if (_items.any((n) => n.id == notification.id)) return;
    _items.insert(0, notification);
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
      final list = await NotificationService(api).list();
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

  Future<void> markAsRead(int id) async {
    final api = _api;
    if (api == null) return;
    try {
      await NotificationService(api).markAsRead(id);
      final index = _items.indexWhere((n) => n.id == id);
      if (index >= 0) {
        final old = _items[index];
        _items[index] = NotificationModel(
          id: old.id,
          message: old.message,
          readAt: DateTime.now().toIso8601String(),
          isRead: true,
          createdAt: old.createdAt,
        );
        notifyListeners();
      } else {
        await refresh();
      }
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  bool _sameList(List<NotificationModel> next) {
    if (next.length != _items.length) return false;
    for (var i = 0; i < next.length; i++) {
      if (next[i].id != _items[i].id || next[i].isRead != _items[i].isRead) {
        return false;
      }
    }
    return true;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_started) refresh();
    });
  }
}
