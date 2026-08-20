import '../core/api_client.dart';
import '../models/notification_model.dart';

class NotificationService {
  NotificationService(this._api);

  final ApiClient _api;

  Future<List<NotificationModel>> list() async {
    final res = await _api.get<List<NotificationModel>>(
      '/notifications',
      parser: (raw) {
        if (raw is! List) return <NotificationModel>[];
        return raw
            .whereType<Map<String, dynamic>>()
            .map(NotificationModel.fromJson)
            .toList();
      },
    );
    return res.data ?? [];
  }

  Future<void> markAsRead(int id) async {
    await _api.post('/notifications/$id/read');
  }
}
