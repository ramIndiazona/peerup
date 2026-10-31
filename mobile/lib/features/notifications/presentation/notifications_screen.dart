import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/app_notification.dart';
import '../../../models/enums.dart';
import '../bloc/notifications_cubit.dart';

const Color _bg = Color(0xFF0B1020);
const Color _surface = Color(0xFF151B30);
const Color _muted = Color(0xFF9AA5C4);
const Color _accent = Color(0xFF9B8CFF);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<NotificationsCubit>();
      if (cubit.state.isInitial) {
        cubit.load();
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      context.read<NotificationsCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),

        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        actions: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            buildWhen: (a, b) => a.unreadCount != b.unreadCount,
            builder: (context, state) {
              if (state.unreadCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed:
                    () => context.read<NotificationsCubit>().markAllRead(),
                child: const Text(
                  'Mark all read',
                  style: TextStyle(color: _accent),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          if (state.isLoading || state.isInitial) {
            return const Center(
              child: CircularProgressIndicator(color: _accent),
            );
          }
          if (state.hasError && state.items.isEmpty) {
            return _ErrorView(
              error: state.error,
              onRetry: () => context.read<NotificationsCubit>().load(),
            );
          }
          if (state.isEmpty) {
            return _EmptyView(
              onRefresh: () => context.read<NotificationsCubit>().refresh(),
            );
          }
          return RefreshIndicator(
            color: _accent,
            backgroundColor: _surface,
            onRefresh: () => context.read<NotificationsCubit>().refresh(),
            child: ListView.separated(
              controller: _controller,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: state.items.length + 1,
              separatorBuilder:
                  (_, __) => const Divider(
                    height: 1,
                    indent: 76,
                    color: Color(0x22FFFFFF),
                  ),
              itemBuilder: (context, i) {
                if (i == state.items.length) {
                  return _Footer(loadingMore: state.loadingMore);
                }
                final n = state.items[i];
                return _NotificationTile(
                  notification: n,
                  onTap: () {
                    if (!n.isRead) {
                      context.read<NotificationsCubit>().markRead(n.id);
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatefulWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _accepting = false;

  AppNotification get notification => widget.notification;

  bool get _isPendingFriendRequest {
    final data = notification.data;
    return data?['kind'] == 'FRIEND_REQUEST' && data?['requestId'] is String;
  }

  IconData get _icon => switch (notification.type) {
    NotificationTypeEnum.subscription => Icons.workspace_premium_outlined,
    NotificationTypeEnum.streak => Icons.local_fire_department_outlined,
    NotificationTypeEnum.reminder => Icons.alarm_rounded,
    NotificationTypeEnum.system => Icons.notifications_outlined,
  };

  Future<void> _accept() async {
    if (_accepting) return;
    setState(() => _accepting = true);

    final ok = await context
        .read<NotificationsCubit>()
        .acceptFriendRequest(notification);

    if (!mounted) return;
    setState(() => _accepting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Friend request accepted.'
              : 'Unable to accept friend request.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return ListTile(
      onTap: widget.onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color:
              unread
                  ? _accent.withValues(alpha: 0.18)
                  : _surface.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(_icon, color: _accent, size: 22),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          color: Colors.white,
          fontWeight: unread ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        notification.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _muted, height: 1.3),
      ),
      trailing:
          _isPendingFriendRequest
              ? TextButton(
                onPressed: _accepting ? null : _accept,
                child:
                    _accepting
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _accent,
                          ),
                        )
                        : const Text(
                          'Accept',
                          style: TextStyle(
                            color: _accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
              )
              : unread
              ? const SizedBox(
                width: 10,
                height: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                  ),
                ),
              )
              : null,
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.loadingMore});

  final bool loadingMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child:
          loadingMore
              ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _accent,
                  ),
                ),
              )
              : const SizedBox(height: 40),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _accent,
      backgroundColor: _surface,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 140),
          Icon(Icons.notifications_none_rounded, size: 52, color: _muted),
          SizedBox(height: 12),
          Center(
            child: Text(
              'No notifications yet',
              style: TextStyle(color: _muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44, color: _muted),
            const SizedBox(height: 12),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _accent),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
