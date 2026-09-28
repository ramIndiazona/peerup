import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/load_state.dart';
import '../../../core/widgets/async_content.dart';
import '../../../models/app_notification.dart';
import '../../../models/enums.dart';
import '../bloc/notifications_cubit.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final cubit = context.read<NotificationsCubit>();
      if (!cubit.state.isLoaded && !cubit.state.isLoading) {
        cubit.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            onPressed: () => context.read<NotificationsCubit>().markAllRead(),
          ),
        ],
      ),
      body: BlocBuilder<NotificationsCubit, LoadState<List<AppNotification>>>(
        builder: (context, state) {
          final items = state.value;
          return AsyncContent<List<AppNotification>>(
            value: state,
            empty: items?.isEmpty ?? false,
            emptyView: const _EmptyView(),
            data:
                (list) => RefreshIndicator(
                  onRefresh: () => context.read<NotificationsCubit>().load(),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: list.length + 1,
                    separatorBuilder:
                        (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, i) {
                      if (i == list.length) return const SizedBox(height: 80);
                      final n = list[i];
                      return _NotificationTile(
                        notification: n,
                        onTap: () => _open(context, n),
                      );
                    },
                  ),
                ),
          );
        },
      ),
    );
  }

  void _open(BuildContext context, AppNotification n) {
    context.read<NotificationsCubit>().markRead(n.id);
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !notification.isRead;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            unread
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          switch (notification.type) {
            NotificationTypeEnum.subscription =>
              Icons.workspace_premium_outlined,
            NotificationTypeEnum.streak => Icons.local_fire_department_outlined,
            NotificationTypeEnum.reminder => Icons.alarm_rounded,
            NotificationTypeEnum.system => Icons.notifications_outlined,
          },
          color: theme.colorScheme.primary,
          size: 22,
        ),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        notification.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing:
          unread
              ? Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              )
              : null,
      onTap: onTap,
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_none_rounded, size: 48),
          const SizedBox(height: 12),
          const Text('No notifications yet'),
        ],
      ),
    );
  }
}
