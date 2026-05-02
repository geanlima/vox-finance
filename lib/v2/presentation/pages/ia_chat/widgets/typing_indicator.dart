import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    Widget dot(int index) {
      final delay = index * 0.2;
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = ((_controller.value + delay) % 1.0);
          final scale = 0.5 + 0.5 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.75),
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot(0),
          const SizedBox(width: 6),
          dot(1),
          const SizedBox(width: 6),
          dot(2),
        ],
      ),
    );
  }
}
