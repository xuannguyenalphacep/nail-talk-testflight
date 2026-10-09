import 'package:flutter/material.dart';

import '../audio/game_audio.dart';

class GptButton extends StatefulWidget {
  const GptButton({
    required this.assetPath,
    required this.semanticLabel,
    this.onPressed,
    this.padding = EdgeInsets.zero,
    this.visualScale = 1,
    super.key,
  });

  final String assetPath;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final EdgeInsets padding;
  final double visualScale;

  @override
  State<GptButton> createState() => _GptButtonState();
}

class _GptButtonState extends State<GptButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  bool _hovered = false;

  late final AnimationController _shineController;

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didUpdateWidget(covariant GptButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null) {
      _pressed = false;
      _hovered = false;
      _shineController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  void _syncMotion() {
    final bool active = widget.onPressed != null && (_pressed || _hovered);
    if (active && !_shineController.isAnimating) {
      _shineController.repeat();
      return;
    }
    if (!active && _shineController.isAnimating) {
      _shineController
        ..stop()
        ..value = 0;
    }
  }

  void _setPressed(bool value) {
    if (!mounted) {
      return;
    }
    setState(() => _pressed = value);
    _syncMotion();
  }

  void _setHovered(bool value) {
    if (!mounted) {
      return;
    }
    setState(() => _hovered = value);
    _syncMotion();
  }

  void _handleTap() {
    GameAudio.tap();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    final bool active = enabled && (_hovered || _pressed);
    final double scale = _pressed ? 0.955 : (_hovered ? 1.018 : 1);
    final double opacity = enabled ? 1 : 0.48;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: enabled ? (_) => _setHovered(true) : null,
        onExit: enabled ? (_) => _setHovered(false) : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _handleTap : null,
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          onTapCancel: enabled ? () => _setPressed(false) : null,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: active
                        ? const Color(0xAA37D9FF)
                        : const Color(0x330B92B5),
                    blurRadius: active ? 28 : 12,
                    spreadRadius: active ? 2 : 0,
                  ),
                  if (_pressed)
                    const BoxShadow(
                      color: Color(0x88FFD681),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              active
                                  ? const Color(0x4438E6FF)
                                  : const Color(0x221FC3E5),
                              const Color(0x00000000),
                              active
                                  ? const Color(0x33FFD36E)
                                  : const Color(0x111FC3E5),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: widget.visualScale,
                        child: Padding(
                          padding: widget.padding,
                          child: Image.asset(
                            widget.assetPath,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                    ),
                    if (enabled)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _shineController,
                            builder: (BuildContext context, Widget? child) {
                              final double shift =
                                  _shineController.value * 2.4 - 1.2;
                              return Opacity(
                                opacity: active ? 0.45 : 0,
                                child: Transform.translate(
                                  offset: Offset(shift * 180, 0),
                                  child: Transform.rotate(
                                    angle: -0.35,
                                    child: const DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: <Color>[
                                            Colors.transparent,
                                            Color(0x99FFFFFF),
                                            Colors.transparent,
                                          ],
                                          stops: <double>[0.32, 0.5, 0.68],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
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
