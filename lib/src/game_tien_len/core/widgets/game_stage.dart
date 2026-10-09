import 'package:flutter/material.dart';

import 'ambient_effects.dart';

class GameStage extends StatelessWidget {
  const GameStage({
    required this.backgroundAsset,
    required this.stageWidth,
    required this.stageHeight,
    required this.child,
    super.key,
  });

  final String backgroundAsset;
  final double stageWidth;
  final double stageHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ColoredBox(
        color: const Color(0xFF031622),
        child: SafeArea(
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: SizedBox(
                  width: stageWidth,
                  height: stageHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(backgroundAsset),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        const _StageColorGrade(),
                        const GameAmbientEffects(),
                        const _StageGlassFrame(),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StageColorGrade extends StatelessWidget {
  const _StageColorGrade();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: const <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x18000810),
                  Color(0x00000000),
                  Color(0x5200060B),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.1),
                radius: 0.92,
                colors: <Color>[Color(0x14FFD36E), Color(0x00000000)],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, 1.05),
                radius: 0.72,
                colors: <Color>[Color(0x24E8A640), Color(0x00132230)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageGlassFrame extends StatelessWidget {
  const _StageGlassFrame();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0x88F6C565), width: 2),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0xAA06131F),
              blurRadius: 32,
              spreadRadius: -4,
            ),
            BoxShadow(color: Color(0x55E8A640), blurRadius: 24),
          ],
        ),
      ),
    );
  }
}
