import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Calm rain-on-water ambient background for auth screens.
///
/// Pure UI: no network, no database. Honors reduced-motion preferences.
class AuthAmbientBackground extends StatefulWidget {
  const AuthAmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AuthAmbientBackground> createState() => _AuthAmbientBackgroundState();
}

class _AuthAmbientBackgroundState extends State<AuthAmbientBackground>
    with SingleTickerProviderStateMixin {
  static const _cycle = Duration(milliseconds: 14000);

  late final AnimationController _controller;
  late final List<_RippleSeed> _seeds;
  late final List<_DriftDot> _dots;
  late final List<_HorizonLine> _horizons;

  @override
  void initState() {
    super.initState();
    _seeds = _RippleSeed.generate(count: 10, seed: 42);
    _dots = _DriftDot.generate(count: 18, seed: 77);
    _horizons = _HorizonLine.generate(count: 5, seed: 19);
    _controller = AnimationController(vsync: this, duration: _cycle);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) return;
      _controller.repeat();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                scheme.surfaceContainerLowest,
                scheme.surface,
                Color.lerp(scheme.surface, scheme.tertiaryContainer, 0.22) ??
                    scheme.surface,
              ],
              stops: const [0.0, 0.58, 1.0],
            ),
          ),
        ),
        if (!reduceMotion)
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _RainRipplePainter(
                    progress: _controller.value,
                    seeds: _seeds,
                    dots: _dots,
                    horizons: _horizons,
                    rippleColor: scheme.primary.withValues(alpha: 0.13),
                    dropColor: scheme.tertiary.withValues(alpha: 0.2),
                    accentColor: scheme.onSurface.withValues(alpha: 0.07),
                    lineColor: scheme.primary.withValues(alpha: 0.055),
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),
        widget.child,
      ],
    );
  }
}

class _RippleSeed {
  const _RippleSeed({
    required this.x,
    required this.y,
    required this.phase,
    required this.maxRadiusFactor,
    required this.durationFactor,
  });

  final double x;
  final double y;
  final double phase;
  final double maxRadiusFactor;
  final double durationFactor;

  static List<_RippleSeed> generate({required int count, required int seed}) {
    final random = math.Random(seed);
    return List.generate(count, (i) {
      return _RippleSeed(
        x: 0.08 + random.nextDouble() * 0.84,
        y: 0.18 + random.nextDouble() * 0.68,
        phase: random.nextDouble(),
        maxRadiusFactor: 0.07 + random.nextDouble() * 0.1,
        durationFactor: 0.55 + random.nextDouble() * 0.45,
      );
    });
  }
}

class _DriftDot {
  const _DriftDot({
    required this.x,
    required this.y,
    required this.phase,
    required this.size,
    required this.drift,
  });

  final double x;
  final double y;
  final double phase;
  final double size;
  final double drift;

  static List<_DriftDot> generate({required int count, required int seed}) {
    final random = math.Random(seed);
    return List.generate(count, (_) {
      return _DriftDot(
        x: random.nextDouble(),
        y: random.nextDouble(),
        phase: random.nextDouble(),
        size: 1.0 + random.nextDouble() * 1.8,
        drift: 0.01 + random.nextDouble() * 0.025,
      );
    });
  }
}

class _HorizonLine {
  const _HorizonLine({
    required this.y,
    required this.phase,
    required this.widthFactor,
    required this.x,
  });

  final double y;
  final double phase;
  final double widthFactor;
  final double x;

  static List<_HorizonLine> generate({required int count, required int seed}) {
    final random = math.Random(seed);
    return List.generate(count, (i) {
      return _HorizonLine(
        y: 0.22 + i * 0.14 + random.nextDouble() * 0.04,
        phase: random.nextDouble(),
        widthFactor: 0.35 + random.nextDouble() * 0.4,
        x: 0.08 + random.nextDouble() * 0.2,
      );
    });
  }
}

class _RainRipplePainter extends CustomPainter {
  const _RainRipplePainter({
    required this.progress,
    required this.seeds,
    required this.dots,
    required this.horizons,
    required this.rippleColor,
    required this.dropColor,
    required this.accentColor,
    required this.lineColor,
  });

  final double progress;
  final List<_RippleSeed> seeds;
  final List<_DriftDot> dots;
  final List<_HorizonLine> horizons;
  final Color rippleColor;
  final Color dropColor;
  final Color accentColor;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = math.min(size.width, size.height);
    final wave = math.sin(progress * math.pi * 2);

    // Soft manuscript-like horizon strokes (replace large mist ovals).
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1;
    for (final line in horizons) {
      final breathe =
          0.55 + 0.45 * math.sin((progress + line.phase) * math.pi * 2);
      final y = line.y * size.height + wave * 2.5;
      final startX = line.x * size.width;
      final endX = startX + line.widthFactor * size.width;
      linePaint.color = lineColor.withValues(alpha: lineColor.a * breathe);
      canvas.drawLine(Offset(startX, y), Offset(endX, y), linePaint);
    }

    // Quiet drifting ink dots (like dust over paper / distant fireflies).
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (final dot in dots) {
      final t = (progress + dot.phase) % 1.0;
      final pulse = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * math.pi * 2));
      final dx =
          math.sin((t + dot.phase) * math.pi * 2) * dot.drift * size.width;
      final dy =
          math.cos((t + dot.phase * 0.7) * math.pi * 2) *
          dot.drift *
          size.height *
          0.6;
      dotPaint.color = accentColor.withValues(alpha: accentColor.a * pulse);
      canvas.drawCircle(
        Offset(dot.x * size.width + dx, dot.y * size.height + dy),
        dot.size,
        dotPaint,
      );
    }

    for (final seed in seeds) {
      final local = ((progress + seed.phase) / seed.durationFactor) % 1.0;
      final center = Offset(seed.x * size.width, seed.y * size.height);
      final maxR = seed.maxRadiusFactor * shortest;

      if (local < 0.18) {
        final t = local / 0.18;
        final fallY = center.dy - (1 - Curves.easeIn.transform(t)) * 28;
        final dropOpacity = (1 - t) * 0.9;
        final dropPaint = Paint()
          ..color = dropColor.withValues(alpha: dropColor.a * dropOpacity)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(center.dx, fallY - 7),
          Offset(center.dx, fallY + 3),
          dropPaint,
        );
      }

      if (local >= 0.12) {
        final rippleT = ((local - 0.12) / 0.88).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(rippleT);
        final fade = (1 - rippleT);
        final alphaScale = fade * fade;

        for (var ring = 0; ring < 2; ring++) {
          final ringDelay = ring * 0.12;
          final ringT = ((rippleT - ringDelay) / (1 - ringDelay)).clamp(
            0.0,
            1.0,
          );
          if (ringT <= 0) continue;
          final ringEase = Curves.easeOut.transform(ringT);
          final radius = maxR * (0.25 + 0.75 * ringEase);
          final paint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1 - ring * 0.25
            ..color = rippleColor.withValues(
              alpha: rippleColor.a * alphaScale * (ring == 0 ? 1 : 0.55),
            );
          canvas.drawCircle(center, radius, paint);
        }

        if (rippleT < 0.35) {
          final glowT = 1 - (rippleT / 0.35);
          final glowPaint = Paint()
            ..style = PaintingStyle.fill
            ..color = dropColor.withValues(alpha: dropColor.a * glowT * 0.4);
          canvas.drawCircle(center, 3.2 + eased * 3.5, glowPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RainRipplePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.rippleColor != rippleColor ||
        oldDelegate.dropColor != dropColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.lineColor != lineColor;
  }
}
