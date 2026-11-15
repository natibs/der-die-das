import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/nati_tokens.dart';

/// Sticky glass header like the A1 app's page-header (blur 14, 72% surface).
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.onToggleTheme, this.onLogoLongPress});

  final VoidCallback onToggleTheme;
  final VoidCallback? onLogoLongPress;

  @override
  Widget build(BuildContext context) {
    final t = NatiTheme.of(context);
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 600 || size.height < 500; // phones, incl. landscape

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(color: t.glass, border: Border(bottom: BorderSide(color: t.border))),
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top,
            left: MediaQuery.paddingOf(context).left,
            right: MediaQuery.paddingOf(context).right,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: NatiSize.maxContentWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 24, vertical: size.height < 500 ? 10 : (compact ? 14 : 20)),
                child: Row(
                  children: [
                    // Long-press cycles through the six time-of-day backgrounds.
                    GestureDetector(onLongPress: onLogoLongPress, child: const AppLogo(size: 34)),
                    const SizedBox(width: NatiSize.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Der · Die · Das',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: compact ? 22 : 28, fontWeight: FontWeight.w700, color: t.text, height: 1.15)),
                          const SizedBox(height: 2),
                          Text('German nouns: article, plural & translations',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: compact ? 13 : 15, color: t.textMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: NatiSize.space3),
                    _ThemeToggle(onPressed: onToggleTheme),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = NatiTheme.of(context);
    return Tooltip(
      message: t.isDark ? 'Light mode' : 'Dark mode',
      child: Material(
        color: t.surface,
        shape: CircleBorder(side: BorderSide(color: t.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (c, a) => RotationTransition(turns: a, child: FadeTransition(opacity: a, child: c)),
              child: Icon(
                t.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                key: ValueKey(t.isDark),
                size: 20,
                color: t.isDark ? t.primary : t.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Line-art badge in the style of the A1 logo, with three article dots.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 34});
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = NatiTheme.of(context);
    return CustomPaint(size: Size.square(size), painter: _LogoPainter(t.text, [t.der, t.die, t.das]));
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.stroke, this.dots);
  final Color stroke;
  final List<Color> dots;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 200;
    final p = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(18 * s, 18 * s, 164 * s, 164 * s), Radius.circular(30 * s)), p);
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(Offset((60 + i * 40) * s, 78 * s), 15 * s, Paint()..color = dots[i]);
    }
    canvas.drawLine(Offset(52 * s, 130 * s), Offset(148 * s, 130 * s), p);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.stroke != stroke || old.dots != dots;
}
