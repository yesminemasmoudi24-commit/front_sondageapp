class NotificationModel {
  NotificationModel({
    required this.id,
    required this.message,
    this.readAt,
    required this.isRead,
    this.createdAt,
  });

  final int id;
  final String message;
  final String? readAt;
  final bool isRead;
  final String? createdAt;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: _asInt(json['id']),
      message: json['message'] as String? ?? '',
      readAt: json['read_at']?.toString(),
      isRead: json['is_read'] == true,
      createdAt: json['created_at']?.toString(),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.parse('$value');
}
