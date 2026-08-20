import '../core/api_client.dart';
import '../models/dashboard_model.dart';

class DashboardService {
  DashboardService(this._api);

  final ApiClient _api;

  Future<DashboardModel> fetch() async {
    final res = await _api.get<DashboardModel>(
      '/dashboard',
      parser: (raw) => DashboardModel.fromJson(raw as Map<String, dynamic>),
    );
    return res.data!;
  }
}
