import 'dart:math';

import 'package:flutter/widgets.dart';

/// 左右晃動動畫（答錯回饋），0.4s，±8px 遞減抖動。
class Shake extends StatelessWidget {
  final bool active;
  final Widget child;

  const Shake({super.key, required this.active, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      builder: (context, t, c) => Transform.translate(
        offset: Offset(sin(t * pi * 4) * 8 * (1 - t), 0),
        child: c,
      ),
      child: child,
    );
  }
}
