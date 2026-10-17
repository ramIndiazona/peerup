import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_routes.dart';
import '../../../core/utils/load_state.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../models/friend.dart';
import '../bloc/friends_cubit.dart';

const Color _bg = Color(0xFF0B1020);
const Color _surface = Color(0xFF151B30);
const Color _muted = Color(0xFF9AA5C4);
const Color _accent = Color(0xFF9B8CFF);
const Color _online = Color(0xFF37D67A);

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<FriendsCubit>();
      if (cubit.state.isIdle) cubit.load();
    });
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
          'Messages',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
      ),
      body: BlocBuilder<FriendsCubit, LoadState<List<Friend>>>(
        builder: (context, state) {
          if (state.isIdle || state.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: _accent),
            );
          }
          if (state.hasError) {
            return _ErrorView(
              error: state.error,
              onRetry: () => context.read<FriendsCubit>().load(),
            );
          }

          final friends = state.value ?? const <Friend>[];
          if (friends.isEmpty) {
            return _EmptyView(
              onRefresh: () => context.read<FriendsCubit>().refresh(),
            );
          }

          return RefreshIndicator(
            color: _accent,
            backgroundColor: _surface,
            onRefresh: () => context.read<FriendsCubit>().refresh(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: friends.length,
              separatorBuilder:
                  (_, __) => const Divider(
                    height: 1,
                    indent: 76,
                    color: Color(0x22FFFFFF),
                  ),
              itemBuilder: (context, i) {
                final friend = friends[i];
                return _FriendTile(
                  friend: friend,
                  onTap:
                      () => context.push(
                        AppRoutes.chatWith(friend.id),
                        extra: friend,
                      ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.onTap});

  final Friend friend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          UserAvatar(url: friend.avatar, name: friend.name, radius: 24),
          if (friend.online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: _online,
                  shape: BoxShape.circle,
                  border: Border.all(color: _bg, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        friend.name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        friend.lastMessagePreview?.isNotEmpty == true
            ? friend.lastMessagePreview!
            : (friend.online ? 'Online' : 'Offline'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _muted, fontSize: 13),
      ),
      trailing: const Icon(
        Icons.chat_bubble_outline_rounded,
        color: _muted,
        size: 20,
      ),
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
          Icon(Icons.people_outline_rounded, size: 52, color: _muted),
          SizedBox(height: 12),
          Center(
            child: Text(
              'No friends yet',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 6),
          Center(
            child: Text(
              'Friends you accept will show up here.',
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
