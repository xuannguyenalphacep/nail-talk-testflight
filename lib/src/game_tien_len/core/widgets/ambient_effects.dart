import 'dart:math' as math;

import 'package:flutter/material.dart';

class GameAmbientEffects extends StatefulWidget {
  const GameAmbientEffects({super.key});

  @override
  State<GameAmbientEffects> createState() => _GameAmbientEffectsState();
}

class _GameAmbientEffectsState extends State<GameAmbientEffects>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const List<_AmbientParticle> _particles = <_AmbientParticle>[
    _AmbientParticle(0.08, 0.20, 0.7, 1.8, 0.45),
    _AmbientParticle(0.18, 0.74, 0.5, 1.4, 0.35),
    _AmbientParticle(0.29, 0.32, 0.8, 1.6, 0.42),
    _AmbientParticle(0.39, 0.86, 0.6, 2.1, 0.30),
    _AmbientParticle(0.48, 0.22, 0.45, 1.3, 0.40),
    _AmbientParticle(0.57, 0.68, 0.75, 1.9, 0.34),
    _AmbientParticle(0.69, 0.28, 0.55, 1.5, 0.38),
    _AmbientParticle(0.78, 0.82, 0.65, 2.0, 0.30),
    _AmbientParticle(0.90, 0.38, 0.8, 1.7, 0.42),
    _AmbientParticle(0.96, 0.68, 0.4, 1.2, 0.36),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            return CustomPaint(
              painter: _AmbientPainter(
                progress: _controller.value,
                particles: _particles,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AmbientParticle {
  const _AmbientParticle(this.x, this.y, this.phase, this.speed, this.opacity);

  final double x;
  final double y;
  final double phase;
  final double speed;
  final double opacity;
}

class _AmbientPainter extends CustomPainter {
  const _AmbientPainter({required this.progress, required this.particles});

  final double progress;
  final List<_AmbientParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    _paintLightBeams(canvas, size);

    for (final _AmbientParticle particle in particles) {
      final double cycle = (particle.phase + progress * particle.speed) % 1.0;
      final double x =
          (particle.x + math.sin(cycle * math.pi * 2) * 0.014) * size.width;
      final double y = ((particle.y - cycle * 0.08 + 1) % 1.0) * size.height;
      final double pulse =
          (math.sin(cycle * math.pi * 2) + 1) / 2 * particle.opacity;
      final Color color = Color.lerp(
        const Color(0xFFFFD86B),
        const Color(0xFF8EE8BD),
        particle.x,
      )!.withValues(alpha: pulse);
      final Offset point = Offset(x, y);

      canvas.drawCircle(
        point,
        8,
        Paint()
          ..color = color.withValues(alpha: pulse * 0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawCircle(point, 1.7, Paint()..color = color);

      final double coinSize = 7 + particle.opacity * 10;
      final Offset coinPoint = Offset(
        x + math.sin(cycle * math.pi * 4) * 12,
        y + math.cos(cycle * math.pi * 2) * 7,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: coinPoint,
          width: coinSize * (0.55 + 0.45 * math.sin(cycle * math.pi).abs()),
          height: coinSize,
        ),
        Paint()
          ..shader =
              const LinearGradient(
                colors: <Color>[Color(0xFFFFF3A0), Color(0xFFE7A82C)],
              ).createShader(
                Rect.fromCenter(
                  center: coinPoint,
                  width: coinSize,
                  height: coinSize,
                ),
              )
          ..color = color.withValues(alpha: pulse * 0.52),
      );
    }
  }

  void _paintLightBeams(Canvas canvas, Size size) {
    final Paint paint = Paint()..blendMode = BlendMode.plus;
    for (int index = 0; index < 3; index++) {
      final double wave = math.sin(progress * math.pi * 2 + index * 1.7);
      final double centerX = size.width * (0.22 + index * 0.27 + wave * 0.018);
      final Path path = Path()
        ..moveTo(centerX - 46, 0)
        ..lineTo(centerX + 46, 0)
        ..lineTo(centerX + 160 + wave * 34, size.height)
        ..lineTo(centerX - 160 + wave * 34, size.height)
        ..close();
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0x44FFE4A3).withValues(alpha: 0.15),
          const Color(0x11FFD36E),
          const Color(0x00000000),
        ],
      ).createShader(Offset.zero & size);
      canvas.drawPath(path, paint);
    }

    final double glowPulse = 0.5 + math.sin(progress * math.pi * 2) * 0.5;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.54),
        width: size.width * (0.42 + glowPulse * 0.025),
        height: size.height * 0.16,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0x44FFE49A).withValues(alpha: 0.22 + glowPulse * 0.08),
            const Color(0x00000000),
          ],
        ).createShader(Offset.zero & size)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }

  @override
  bool shouldRepaint(_AmbientPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
