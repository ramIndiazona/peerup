import 'enums.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.type = NotificationTypeEnum.system,
    this.data,
    this.readAt,
  });

  final String id;
  final NotificationTypeEnum type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String? ?? '',
        type: NotificationTypeEnum.fromApi(json['type'] as String?),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        data:
            json['data'] is Map
                ? Map<String, dynamic>.from(json['data'] as Map)
                : null,
        readAt:
            json['readAt'] is String
                ? DateTime.tryParse(json['readAt'] as String)
                : null,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class NotificationListResult {
  const NotificationListResult({required this.items, required this.total});

  final List<AppNotification> items;
  final int total;

  factory NotificationListResult.fromJson(Map<String, dynamic> json) =>
      NotificationListResult(
        items:
            (json['items'] as List? ?? const [])
                .map(
                  (e) => AppNotification.fromJson(
                    (e as Map).cast<String, dynamic>(),
                  ),
                )
                .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
      );
}
