import '../core/api_client.dart';
import '../models/employee_model.dart';

class EmployeeService {
  EmployeeService(this._api);

  final ApiClient _api;

  Future<List<EmployeeModel>> list() async {
    final res = await _api.get<List<EmployeeModel>>(
      '/employees',
      parser: (raw) {
        if (raw is! List) return <EmployeeModel>[];
        return raw
            .whereType<Map<String, dynamic>>()
            .map(EmployeeModel.fromJson)
            .toList();
      },
    );
    return res.data ?? [];
  }

  Future<EmployeeModel> create(Map<String, dynamic> body) async {
    final res = await _api.post<EmployeeModel>(
      '/employees',
      body: body,
      parser: (raw) => EmployeeModel.fromJson(raw as Map<String, dynamic>),
    );
    return res.data!;
  }

  Future<EmployeeModel> update(int id, Map<String, dynamic> body) async {
    final res = await _api.put<EmployeeModel>(
      '/employees/$id',
      body: body,
      parser: (raw) => EmployeeModel.fromJson(raw as Map<String, dynamic>),
    );
    return res.data!;
  }

  Future<void> delete(int id) async {
    await _api.delete('/employees/$id');
  }
}
