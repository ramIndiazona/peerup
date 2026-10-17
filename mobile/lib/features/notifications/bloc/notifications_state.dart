import 'package:equatable/equatable.dart';

import '../../../models/app_notification.dart';

enum NotificationsStatus { initial, loading, loaded, error }

class NotificationsState extends Equatable {
  const NotificationsState({
    this.status = NotificationsStatus.initial,
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.hasMore = false,
    this.loadingMore = false,
    this.error,
  });

  final NotificationsStatus status;
  final List<AppNotification> items;
  final int total;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final Object? error;

  int get unreadCount => items.where((n) => !n.isRead).length;

  bool get isEmpty => status == NotificationsStatus.loaded && items.isEmpty;

  bool get isInitial => status == NotificationsStatus.initial;
  bool get isLoading => status == NotificationsStatus.loading;
  bool get isLoaded => status == NotificationsStatus.loaded;
  bool get hasError => status == NotificationsStatus.error;

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<AppNotification>? items,
    int? total,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    Object? error,
    bool clearError = false,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    status,
    items,
    total,
    page,
    hasMore,
    loadingMore,
    error,
  ];
}
