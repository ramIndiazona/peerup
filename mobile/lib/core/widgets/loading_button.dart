import 'package:flutter/material.dart';

class LoadingButton extends StatefulWidget {
  const LoadingButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.isFilled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool isFilled;

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<LoadingButton> {
  @override
  Widget build(BuildContext context) {
    final button =
        widget.isFilled
            ? FilledButton(
              onPressed: widget.loading ? null : widget.onPressed,
              child: _content(),
            )
            : OutlinedButton(
              onPressed: widget.loading ? null : widget.onPressed,
              child: _content(),
            );
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: widget.loading ? 0.7 : 1,
      child: button,
    );
  }

  Widget _content() {
    if (widget.loading) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      );
    }
    if (widget.icon == null) return Text(widget.label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(widget.icon, size: 20),
        const SizedBox(width: 8),
        Text(widget.label),
      ],
    );
  }
}
