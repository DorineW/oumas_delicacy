import 'package:flutter/material.dart';
import 'colors.dart';

class AppDecorations {
  static BorderRadius radius8 = BorderRadius.circular(8);
  static BorderRadius radius12 = BorderRadius.circular(12);
  static BorderRadius radius16 = BorderRadius.circular(16);
  static BorderRadius radius24 = BorderRadius.circular(24);

  static BoxShadow get softShadow => BoxShadow(
        color: AppColors.primary.withOpacity(0.10),
        blurRadius: 16.0,
        offset: const Offset(0.0, 6.0),
      );

  static BoxShadow get cardShadow => BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 12.0,
        offset: const Offset(0.0, 4.0),
      );

  static BoxShadow get glassShadow => BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 20.0,
        offset: const Offset(0.0, 8.0),
      );
}
