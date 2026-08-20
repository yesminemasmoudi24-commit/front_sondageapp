import '../core/api_client.dart';
import '../models/delegation_model.dart';

class DelegationService {
  DelegationService(this._api);

  final ApiClient _api;

  Future<List<DelegationModel>> list() async {
    final res = await _api.get<List<DelegationModel>>(
      '/delegations',
      parser: (raw) {
        if (raw is! List) return <DelegationModel>[];
        return raw
            .whereType<Map<String, dynamic>>()
            .map(DelegationModel.fromJson)
            .toList();
      },
    );
    return res.data ?? [];
  }

  Future<DelegationModel> create({
    required int delegatedUserId,
    required String startDate,
    required String endDate,
  }) async {
    final res = await _api.post<DelegationModel>(
      '/delegations',
      body: {
        'delegated_user_id': delegatedUserId,
        'start_date': startDate,
        'end_date': endDate,
      },
      parser: (raw) => DelegationModel.fromJson(raw as Map<String, dynamic>),
    );
    return res.data!;
  }

  Future<void> delete(int id) async {
    await _api.delete('/delegations/$id');
  }
}
