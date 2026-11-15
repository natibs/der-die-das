import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/day_phase.dart';
import '../theme/nati_tokens.dart';

/// Full-screen gradient behind everything that follows the local hour, with a
/// blurred "sun" that moves per phase. Dimmed in dark mode exactly like the
/// A1 app (`filter: brightness(.32) saturate(.6)`).
class TimeOfDayBackground extends StatefulWidget {
  const TimeOfDayBackground({super.key, this.overridePhase});

  /// Preview hook (long-press the logo to cycle phases).
  final DayPhase? overridePhase;

  @override
  State<TimeOfDayBackground> createState() => _TimeOfDayBackgroundState();
}

class _TimeOfDayBackgroundState extends State<TimeOfDayBackground> with WidgetsBindingObserver {
  late DayPhase _phase = phaseForHour(DateTime.now().hour);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    final p = phaseForHour(DateTime.now().hour);
    if (p != _phase && mounted) setState(() => _phase = p);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = phaseStyles[widget.overridePhase ?? _phase]!;
    const duration = Duration(milliseconds: 800);
    final dark = NatiTheme.of(context).isDark;

    final scene = AnimatedContainer(
      duration: duration,
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          // CSS 160deg
          begin: const Alignment(-0.34, -0.94),
          end: const Alignment(0.34, 0.94),
          colors: style.colors,
          stops: style.stops,
        ),
      ),
      child: AnimatedAlign(
        duration: duration,
        curve: Curves.easeInOut,
        alignment: style.sunAlign,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: AnimatedContainer(
            duration: duration,
            width: style.sunSize,
            height: style.sunSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [style.sunColor.withValues(alpha: style.sunColor.a * 0.6), style.sunColor.withValues(alpha: 0)],
                stops: const [0, 0.7],
              ),
            ),
          ),
        ),
      ),
    );

    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: dark ? 1 : 0),
        duration: duration,
        builder: (context, t, child) => t == 0
            ? child!
            : ColorFiltered(colorFilter: ColorFilter.matrix(_dimMatrix(t)), child: child),
        child: scene,
      ),
    );
  }

  /// brightness(1 -> .32) * saturate(1 -> .6), interpolated by [t].
  static List<double> _dimMatrix(double t) {
    final b = 1 - 0.68 * t;
    final s = 1 - 0.4 * t;
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final i = 1 - s;
    return [
      (lr * i + s) * b, lg * i * b, lb * i * b, 0, 0,
      lr * i * b, (lg * i + s) * b, lb * i * b, 0, 0,
      lr * i * b, lg * i * b, (lb * i + s) * b, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }
}
