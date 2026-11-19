import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Soft atmospheric sky backdrop with layered cloud formations.
///
/// The clouds are painted procedurally instead of using a bitmap so the effect
/// stays crisp at any resolution and adds no asset weight to the bundle.
class CloudyBackground extends StatelessWidget {
  final Widget child;
  final bool animate;

  const CloudyBackground({
    super.key,
    required this.child,
    this.animate = false,
  });

  /// Sky gradient shared by the static and animated variants.
  ///
  /// The top is deliberately a saturated blue: white clouds need a darker sky
  /// behind them to be visible at all.
  static const LinearGradient skyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF7FB6E0),
      Color(0xFFA3CCEB),
      Color(0xFFCFE4F6),
      Color(0xFFF2F9FE),
    ],
    stops: [0.0, 0.18, 0.46, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    if (!animate) {
      return Container(
        decoration: const BoxDecoration(gradient: skyGradient),
        child: CustomPaint(
          painter: _CloudPainter(),
          child: child,
        ),
      );
    }

    return _AnimatedCloudyBackground(child: child);
  }
}

class _AnimatedCloudyBackground extends StatefulWidget {
  final Widget child;

  const _AnimatedCloudyBackground({required this.child});

  @override
  State<_AnimatedCloudyBackground> createState() =>
      _AnimatedCloudyBackgroundState();
}

class _AnimatedCloudyBackgroundState extends State<_AnimatedCloudyBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 70),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: CloudyBackground.skyGradient,
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _CloudPainter(drift: _controller.value),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _CloudPainter extends CustomPainter {
  /// 0..1 horizontal drift used to slowly move the cloud bank.
  final double drift;

  _CloudPainter({this.drift = 0.0});

  /// Outline colour used for the cartoon cloud edges.
  static const Color _outline = Color(0xFF74ADD8);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    _paintDistantClouds(canvas, size);
    _paintHeroClouds(canvas, size);
  }

  /// Smaller, cooler clouds sitting behind the main bank.
  void _paintDistantClouds(Canvas canvas, Size size) {
    _paintCloud(
      canvas,
      center: Offset(
        size.width * (0.76 + 0.04 * drift),
        size.height * 0.072,
      ),
      width: size.width * 0.40,
      height: size.width * 0.155,
      fill: const Color(0xFFF6FBFF).withValues(alpha: 0.95),
      outlineColor: _outline.withValues(alpha: 0.42),
      outlineWidth: 1.4,
      bumps: const [
        (-0.26, 0.01, 0.16),
        (0.0, -0.09, 0.22),
        (0.26, 0.01, 0.16),
      ],
    );

    _paintCloud(
      canvas,
      center: Offset(
        size.width * (0.14 - 0.03 * drift),
        size.height * 0.175,
      ),
      width: size.width * 0.34,
      height: size.width * 0.135,
      fill: const Color(0xFFF1F9FF).withValues(alpha: 0.92),
      outlineColor: _outline.withValues(alpha: 0.35),
      outlineWidth: 1.2,
      bumps: const [
        (-0.24, 0.01, 0.15),
        (0.0, -0.08, 0.20),
        (0.24, 0.01, 0.15),
      ],
    );
  }

  /// Foreground cumulus drawn across the header band with a defined outline.
  void _paintHeroClouds(Canvas canvas, Size size) {
    _paintCloud(
      canvas,
      center: Offset(size.width * 0.26, size.height * 0.062),
      width: size.width * 0.70,
      height: size.width * 0.29,
      fill: Colors.white,
      outlineColor: _outline,
      outlineWidth: 2.2,
      bumps: const [
        (-0.33, 0.02, 0.17),
        (-0.14, -0.10, 0.22),
        (0.07, -0.14, 0.24),
        (0.27, -0.04, 0.19),
      ],
    );

    _paintCloud(
      canvas,
      center: Offset(size.width * 0.87, size.height * 0.125),
      width: size.width * 0.44,
      height: size.width * 0.185,
      fill: Colors.white.withValues(alpha: 0.98),
      outlineColor: _outline.withValues(alpha: 0.9),
      outlineWidth: 1.8,
      bumps: const [
        (-0.25, 0.01, 0.15),
        (0.0, -0.08, 0.21),
        (0.25, 0.01, 0.15),
      ],
    );
  }

  /// Builds one continuous cartoon cloud: a rounded base with bumps on top,
  /// filled white and stroked with a blue outline.
  void _paintCloud(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
    required Color fill,
    required Color outlineColor,
    required double outlineWidth,
    required List<(double, double, double)> bumps,
  }) {
    final halfWidth = width / 2;

    // Union every lobe into a single path. Without this the stroke traces each
    // circle separately, so interior arcs show through the cloud body.
    final baseRect = Rect.fromCenter(
      center: center,
      width: width,
      height: height,
    );

    Path merged = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            baseRect.left,
            baseRect.top + height * 0.34,
            baseRect.right,
            baseRect.bottom,
          ),
          Radius.circular(height * 0.40),
        ),
      );

    for (final (dx, dy, r) in bumps) {
      final lobe = Path()
        ..addOval(
          Rect.fromCircle(
            center: Offset(
              center.dx + dx * width,
              center.dy + dy * height,
            ),
            radius: r * width,
          ),
        );
      merged = Path.combine(PathOperation.union, merged, lobe);
    }

    // Stroke wide, fill over it, then re-stroke at true width for a clean edge.
    if (outlineWidth > 0) {
      canvas.drawPath(
        merged,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = outlineWidth * 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = outlineColor,
      );
    }

    canvas.drawPath(
      merged,
      Paint()
        ..style = PaintingStyle.fill
        ..color = fill,
    );

    if (outlineWidth > 0) {
      canvas.drawPath(
        merged,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = outlineWidth
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = outlineColor,
      );
    }

    // Soft highlight along the upper-left of the cloud.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          center.dx - halfWidth * 0.16,
          center.dy - height * 0.16,
        ),
        width: width * 0.42,
        height: height * 0.28,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(width * 0.025, 3.0),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _CloudPainter oldDelegate) {
    return oldDelegate.drift != drift;
  }
}

/// Convenience wrapper matching the previous gradient background usage.
class AtmosphericBackground extends StatelessWidget {
  final Widget child;

  const AtmosphericBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CloudyBackground(child: child);
  }
}

/// Solid fallback colour used behind translucent surfaces.
const Color kAtmosphericBase = AppColors.background;
