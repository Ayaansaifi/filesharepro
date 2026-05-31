import 'package:flutter/material.dart';

/// Custom AnimatedWidget wrapper — named differently to avoid
/// conflict with Flutter's built-in AnimatedBuilder.
class AppAnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AppAnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
