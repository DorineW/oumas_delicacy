import 'package:flutter/material.dart';

class AppDecorations {
  static BorderRadius radius12 = BorderRadius.circular(12);
  static BorderRadius radius24 = BorderRadius.circular(24);

  static BoxShadow get softShadow => BoxShadow(
        color: Colors.grey.withOpacity(.15),
        blurRadius: 16,
        offset: const Offset(0, 6),
      );
  static BoxShadow get cardShadow => BoxShadow(
        color: Colors.black.withOpacity(.05),
        blurRadius: 12,
        offset: const Offset(0, 4),
      );
}