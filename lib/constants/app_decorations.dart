import 'package:flutter/material.dart';
import 'colors.dart';

class AppDecorations {
  static BorderRadius radius8 = BorderRadius.circular(8);
  static BorderRadius radius12 = BorderRadius.circular(12);
  static BorderRadius radius16 = BorderRadius.circular(16);
  static BorderRadius radius24 = BorderRadius.circular(24);

  static BoxShadow get softShadow => BoxShadow(
        color: AppColors.primary.withOpacity(.10),
        blurRadius: 16,
        offset: const Offset(0, 6),
      );

  static BoxShadow get cardShadow => BoxShadow(
        color: Colors.black.withOpacity(.05),
        blurRadius: 12,
        offset: const Offset(0, 4),
      );

  static BoxShadow get glassShadow => BoxShadow(
        color: Colors.black.withOpacity(.08),
        blurRadius: 20,
        offset: const Offset(0, 8),
      );
}
