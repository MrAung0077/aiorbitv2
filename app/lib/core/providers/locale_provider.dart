import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null);

  void useSystemLocale() {
    state = null;
  }

  void setEnglish() {
    state = const Locale('en');
  }

  void setMyanmar() {
    state = const Locale('my');
  }

  void setLocale(Locale locale) {
    state = locale;
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>(
  (ref) => LocaleNotifier(),
);
