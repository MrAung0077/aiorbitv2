import 'package:flutter/widgets.dart';

abstract final class AppRadius {
  static const double button = 16;
  static const double card = 20;
  static const double dialog = 24;

  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(button),
  );

  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );

  static const BorderRadius dialogRadius = BorderRadius.all(
    Radius.circular(dialog),
  );
}
