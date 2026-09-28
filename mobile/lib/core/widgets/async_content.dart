import 'package:flutter/material.dart';

import '../utils/load_state.dart';

class AsyncContent<T> extends StatelessWidget {
  const AsyncContent({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
    this.empty = false,
    this.emptyView,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  final LoadState<T> value;
  final Widget Function(T data) data;
  final Widget? loading;
  final Widget Function(Object error, StackTrace? stack)? error;
  final bool empty;
  final Widget? emptyView;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    switch (value.status) {
      case LoadStatus.loaded:
        if (empty && emptyView != null) return emptyView!;
        return data(value.requireData());
      case LoadStatus.idle:
      case LoadStatus.loading:
        return loading ??
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            );
      case LoadStatus.error:
        return error != null
            ? error!(value.error!, null)
            : _ErrorView(error: value.error!, padding: padding);
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.padding});

  final Object error;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
