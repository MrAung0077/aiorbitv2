import 'dart:async';

import 'package:flutter/material.dart';

class StreamingText extends StatefulWidget {
  const StreamingText({
    super.key,
    required this.text,
    this.style,
    this.charactersPerTick = 2,
    this.tick = const Duration(milliseconds: 18),
    this.onCompleted,
  });

  final String text;
  final TextStyle? style;
  final int charactersPerTick;
  final Duration tick;
  final VoidCallback? onCompleted;

  @override
  State<StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<StreamingText> {
  Timer? _timer;
  int _visibleLength = 0;
  bool _didComplete = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant StreamingText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.text != widget.text) {
      _timer?.cancel();
      _visibleLength = 0;
      _didComplete = false;
      _start();
    }
  }

  void _start() {
    if (widget.text.isEmpty) {
      _complete();
      return;
    }

    _timer = Timer.periodic(widget.tick, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_visibleLength >= widget.text.length) {
        timer.cancel();
        _complete();
        return;
      }

      setState(() {
        _visibleLength += widget.charactersPerTick;

        if (_visibleLength > widget.text.length) {
          _visibleLength = widget.text.length;
        }
      });

      if (_visibleLength >= widget.text.length) {
        timer.cancel();
        _complete();
      }
    });
  }

  void _complete() {
    if (_didComplete) {
      return;
    }

    _didComplete = true;
    widget.onCompleted?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(widget.text.substring(0, _visibleLength), style: widget.style);
  }
}
