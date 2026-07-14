import 'package:flutter/material.dart';

abstract final class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
}
