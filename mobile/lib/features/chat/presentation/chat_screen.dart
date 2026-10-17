import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/user_avatar.dart';
import '../../../models/chat.dart';
import '../../../models/friend.dart';
import '../bloc/chat_cubit.dart';

const Color _bg = Color(0xFF0B1020);
const Color _surface = Color(0xFF151B30);
const Color _muted = Color(0xFF9AA5C4);
const Color _accent = Color(0xFF9B8CFF);
const Color _online = Color(0xFF37D67A);

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.friendId, this.friend});

  final String friendId;
  final Friend? friend;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _canSend = false;

  /// Id of the newest message we have already auto-scrolled to.
  ///
  /// Lets the listener distinguish "a message arrived / was confirmed"
  /// (scroll down) from "older history was prepended" (keep the viewport).
  String? _lastMessageId;

  @override
  void initState() {
    super.initState();
    _input.addListener(_onInputChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<ChatCubit>();
      if (cubit.state.isInitial) cubit.open();
    });
  }

  @override
  void dispose() {
    _input.removeListener(_onInputChanged);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    final can = _input.text.trim().isNotEmpty;
    if (can != _canSend) setState(() => _canSend = can);
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent;
    if (animate) {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scroll.jumpTo(target);
    }
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final cubit = context.read<ChatCubit>();
    if (cubit.state.sending) return;
    _input.clear();
    cubit.send(text);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.friend?.name ?? 'Chat';
    final online = widget.friend?.online ?? false;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,

        surfaceTintColor: Colors.transparent,

        scrolledUnderElevation: 0,
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),

        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(url: widget.friend?.avatar, name: title, radius: 18),
            const SizedBox(width: 10),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  online ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: online ? _online : _muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          BlocBuilder<ChatCubit, ChatState>(
            buildWhen: (a, b) => a.connected != b.connected,
            builder:
                (context, state) =>
                    state.connected
                        ? const SizedBox.shrink()
                        : const _ConnectionBanner(),
          ),
          Expanded(
            child: BlocConsumer<ChatCubit, ChatState>(
              listenWhen: (a, b) =>
                  a.messages != b.messages || a.status != b.status,
              listener: (context, state) {
                final newestId =
                    state.messages.isEmpty ? null : state.messages.last.id;
                final newestChanged = newestId != _lastMessageId;
                _lastMessageId = newestId;
                if (!newestChanged || newestId == null) return;
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );
              },
              builder: (context, state) {
                if (state.isInitial || state.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: _accent),
                  );
                }
                if (state.hasError && state.messages.isEmpty) {
                  return _ErrorView(
                    error: state.error,
                    onRetry: () => context.read<ChatCubit>().retry(),
                  );
                }
                if (state.isEmpty) {
                  return const _EmptyView();
                }
                final showLoader = state.hasMore || state.loadingOlder;
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: state.messages.length + (showLoader ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (showLoader && i == 0) {
                      return _OlderLoader(
                        loading: state.loadingOlder,
                        onLoad: () => context.read<ChatCubit>().loadOlder(),
                      );
                    }
                    final message = state.messages[i - (showLoader ? 1 : 0)];
                    final mine =
                        message.senderId ==
                        context.read<ChatCubit>().currentUserId;
                    return _MessageBubble(
                      message: message,
                      mine: mine,
                      onDiscard:
                          message.failed
                              ? () => context.read<ChatCubit>().discardFailed(
                                message.id,
                              )
                              : null,
                    );
                  },
                );
              },
            ),
          ),
          _Composer(controller: _input, canSend: _canSend, onSend: _send),
        ],
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0x33FF5A7A),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: const Text(
        'Reconnecting… messages may be delayed',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}

class _OlderLoader extends StatelessWidget {
  const _OlderLoader({required this.loading, required this.onLoad});

  final bool loading;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _accent,
                ),
              )
            : TextButton(
                onPressed: onLoad,
                child: const Text(
                  'Load earlier messages',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    this.onDiscard,
  });

  final ChatMessage message;
  final bool mine;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.Hm().format(message.createdAt.toLocal());
    final bubbleColor = mine ? _accent : _surface;
    final textColor = mine ? Colors.white : const Color(0xFFE7EAF5);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onDiscard,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                message.content,
                style: TextStyle(color: textColor, height: 1.3),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.65),
                      fontSize: 10,
                    ),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.failed
                          ? Icons.error_outline_rounded
                          : message.pending
                          ? Icons.schedule_rounded
                          : Icons.done_rounded,
                      size: 13,
                      color:
                          message.failed
                              ? const Color(0xFFFF5A7A)
                              : textColor.withValues(alpha: 0.75),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.canSend,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool canSend;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: _bg,
          border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  hintStyle: const TextStyle(color: _muted),
                  filled: true,
                  fillColor: _surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final enabled = canSend && value.text.trim().isNotEmpty;
                return IconButton(
                  onPressed: enabled ? onSend : null,
                  style: IconButton.styleFrom(
                    backgroundColor: enabled ? _accent : _surface,
                  ),
                  icon: Icon(
                    Icons.send_rounded,
                    color: enabled ? Colors.white : _muted,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 52, color: _muted),
          SizedBox(height: 12),
          Text('Say hello 👋', style: TextStyle(color: _muted)),
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
