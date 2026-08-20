class ApiResponse<T> {
  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.errors,
  });

  final bool success;
  final String message;
  final T? data;
  final dynamic errors;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json, {
    T Function(dynamic raw)? parser,
  }) {
    final raw = json['data'];
    return ApiResponse<T>(
      success: json['success'] == true,
      message: (json['message'] as String?) ?? '',
      data: raw == null || parser == null ? raw as T? : parser(raw),
      errors: json['errors'],
    );
  }
}
