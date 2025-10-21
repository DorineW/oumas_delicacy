import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_decorations.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final double opacity;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.opacity = 0.65,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? AppDecorations.radius16,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
            borderRadius: borderRadius ?? AppDecorations.radius16,
            boxShadow: [AppDecorations.glassShadow],
          ),
          child: child,
        ),
      ),
    );
  }
}
