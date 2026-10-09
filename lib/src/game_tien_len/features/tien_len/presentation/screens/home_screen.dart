import 'package:flutter/material.dart';

import '../../../../core/audio/game_audio.dart';
import '../../../../core/widgets/card_view.dart';
import '../../../../core/widgets/game_stage.dart';
import '../../../../core/widgets/profile_chip.dart';
import '../../data/game_data.dart';
import 'active_tables_screen.dart';
import 'waiting_room_screen.dart';

const String _lobbySparkleGif =
    'assets/game_tien_len/effects/lobby_gold_sparkle.gif';
const String _titleLogoAsset =
    'assets/game_tien_len/branding/title_tien_len_gold.png';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const String _stageBackground =
      'assets/game_tien_len/backgrounds/home_stage_premium.jpg';

  void _openQuickPlay(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WaitingRoomScreen(room: demoRooms.first),
      ),
    );
  }

  void _openActiveTables(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ActiveTablesScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return GameStage(
      backgroundAsset: _stageBackground,
      stageWidth: 1672,
      stageHeight: 941,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(46, 28, 46, 34),
        child: Stack(
          children: <Widget>[
            const Positioned.fill(child: _PaintedCasinoBackdrop()),
            const Positioned.fill(child: _LobbySparkleOverlay()),
            const Align(
              alignment: Alignment.topLeft,
              child: ProfileChip(name: 'Tây Bích 88', balance: 12500),
            ),
            const Align(alignment: Alignment.topRight, child: _RoomSignal()),
            Align(
              alignment: const Alignment(0, -0.18),
              child: SizedBox(
                width: 1120,
                height: 730,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    const Positioned(top: 80, child: _TitleBackdrop()),
                    Positioned(
                      top: 98,
                      child: SizedBox(
                        width: 760,
                        height: 220,
                        child: _GoldTitle(),
                      ),
                    ),
                    const Positioned(top: 345, child: _HeroCardFan()),
                    Positioned(
                      bottom: 56,
                      child: _MainPlayButton(
                        onPressed: () => _openQuickPlay(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 118,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Spacer(flex: 5),
                    Expanded(
                      flex: 4,
                      child: _SecondaryActionButton(
                        label: 'Bàn đang chơi',
                        subtitle: 'Xem phòng đang mở',
                        icon: Icons.groups_2_rounded,
                        onPressed: () => _openActiveTables(context),
                      ),
                    ),
                    const Spacer(flex: 5),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaintedCasinoBackdrop extends StatelessWidget {
  const _PaintedCasinoBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset(
          HomeScreen._stageBackground,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) {
            return CustomPaint(painter: _CasinoBackdropPainter());
          },
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0x22020B12),
                Color(0x00020B12),
                Color(0x44020B12),
              ],
              stops: <double>[0, 0.52, 1],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.04),
              radius: 0.92,
              colors: <Color>[
                Color(0x00000000),
                Color(0x00000000),
                Color(0x33000610),
              ],
              stops: <double>[0, 0.68, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _CasinoBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0x22002035),
            Color(0x0015C8E6),
            Color(0x4400040B),
          ],
        ).createShader(rect),
    );

    _drawWindow(canvas, size);
    _drawCity(canvas, size);
    _drawTable(canvas, size);
  }

  void _drawWindow(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = const Color(0x334CEAFF)
      ..strokeWidth = 2;
    for (final double xFactor in <double>[0.16, 0.29, 0.42, 0.58, 0.72, 0.86]) {
      final double x = size.width * xFactor;
      canvas.drawLine(Offset(x, 68), Offset(x, size.height * 0.54), linePaint);
    }
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.46),
      Offset(size.width * 0.92, size.height * 0.46),
      Paint()
        ..color = const Color(0x264CEAFF)
        ..strokeWidth = 2,
    );
  }

  void _drawCity(Canvas canvas, Size size) {
    const List<double> heights = <double>[
      0.16,
      0.22,
      0.12,
      0.25,
      0.18,
      0.29,
      0.14,
      0.23,
      0.31,
      0.2,
      0.27,
      0.17,
    ];
    final double baseY = size.height * 0.48;
    final double startX = size.width * 0.18;
    final double step = size.width * 0.055;
    for (int i = 0; i < heights.length; i++) {
      final double buildingWidth = step * 0.58;
      final double left = startX + i * step;
      final double top = baseY - size.height * heights[i];
      final RRect tower = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, buildingWidth, baseY - top),
        const Radius.circular(4),
      );
      canvas.drawRRect(tower, Paint()..color = const Color(0x26041422));
      for (int floor = 0; floor < 6; floor++) {
        if ((floor + i).isOdd) {
          canvas.drawCircle(
            Offset(left + buildingWidth * 0.5, top + 16 + floor * 16),
            2.2,
            Paint()
              ..color = i.isEven
                  ? const Color(0xA938DFFF)
                  : const Color(0xA9FFD36E),
          );
        }
      }
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, baseY + 15),
        width: size.width * 0.62,
        height: 18,
      ),
      Paint()
        ..shader =
            const RadialGradient(
              colors: <Color>[Color(0x6638DFFF), Color(0x00000000)],
            ).createShader(
              Rect.fromCenter(
                center: Offset(size.width * 0.5, baseY + 15),
                width: size.width * 0.62,
                height: 22,
              ),
            ),
    );
  }

  void _drawTable(Canvas canvas, Size size) {
    final Offset center = Offset(size.width * 0.5, size.height * 0.82);
    final Rect table = Rect.fromCenter(
      center: center,
      width: size.width * 0.88,
      height: size.height * 0.36,
    );
    canvas.drawOval(
      table,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.15),
          radius: 0.74,
          colors: <Color>[
            Color(0x9941DCC9),
            Color(0x66056D77),
            Color(0x0000202B),
          ],
        ).createShader(table),
    );
    for (final double inset in <double>[0, 28, 58]) {
      canvas.drawOval(
        table.deflate(inset),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = inset == 0 ? 3 : 1.2
          ..color = inset == 0
              ? const Color(0x66FFD36E)
              : const Color(0x4A38DFFF),
      );
    }
    canvas.drawCircle(
      center,
      30,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0x55FFD36E),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LobbySparkleOverlay extends StatelessWidget {
  const _LobbySparkleOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Align(
            alignment: const Alignment(0, 0.04),
            child: SizedBox(
              width: 760,
              height: 390,
              child: Image.asset(
                _lobbySparkleGif,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, 0.16),
                radius: 0.66,
                colors: <Color>[
                  Color(0x00FFD36E),
                  Color(0x12FFD36E),
                  Color(0x00000000),
                ],
                stops: <double>[0, 0.48, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldTitle extends StatelessWidget {
  const _GoldTitle();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _titleLogoAsset,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

class _RoomSignal extends StatelessWidget {
  const _RoomSignal();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x9A061F32),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x7738DFFF)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x5538DFFF), blurRadius: 16),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.wifi_tethering, color: Color(0xFF79F3FF), size: 20),
            SizedBox(width: 8),
            Text(
              'Sảnh Tiến Lên',
              style: TextStyle(
                color: Color(0xFFD7FBFF),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBackdrop extends StatelessWidget {
  const _TitleBackdrop();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 760,
      height: 205,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(42),
          gradient: const RadialGradient(
            center: Alignment(0, 0.2),
            radius: 0.92,
            colors: <Color>[Color(0x22000000), Color(0x00000000)],
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x33F2B84B),
              blurRadius: 38,
              spreadRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCardFan extends StatelessWidget {
  const _HeroCardFan();

  static const List<PlayingCardData> _cards = <PlayingCardData>[
    PlayingCardData('10', CardSuit.spades),
    PlayingCardData('J', CardSuit.hearts),
    PlayingCardData('Q', CardSuit.clubs),
    PlayingCardData('K', CardSuit.diamonds),
    PlayingCardData('A', CardSuit.spades),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 610,
      height: 230,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          const Positioned(
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0x3338DFFF),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0xBB38DFFF),
                    blurRadius: 42,
                    spreadRadius: 18,
                  ),
                  BoxShadow(
                    color: Color(0x88FFD36E),
                    blurRadius: 34,
                    spreadRadius: 7,
                  ),
                ],
              ),
              child: SizedBox(width: 330, height: 18),
            ),
          ),
          const Positioned(left: 8, bottom: 8, child: _ChipStack()),
          const Positioned(
            right: 6,
            bottom: 10,
            child: _ChipStack(compact: true),
          ),
          ...List<Widget>.generate(_cards.length, (int index) {
            final double normalized = index / (_cards.length - 1) * 2 - 1;
            return Transform.translate(
              offset: Offset(normalized * 82, normalized.abs() * 14),
              child: Transform.rotate(
                angle: normalized * 0.18,
                child: SizedBox(
                  width: 126,
                  height: 184,
                  child: PlayingCardView(card: _cards[index]),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ChipStack extends StatelessWidget {
  const _ChipStack({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 28 : 34;
    return SizedBox(
      width: compact ? 96 : 118,
      height: compact ? 80 : 96,
      child: Stack(
        children: List<Widget>.generate(8, (int index) {
          final bool gold = index.isEven;
          return Positioned(
            left: (index % 4) * (size * 0.56),
            bottom: (index ~/ 4) * (size * 0.45),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gold
                      ? const <Color>[Color(0xFFFFEF9C), Color(0xFFE2A228)]
                      : const <Color>[Color(0xFF69F2FF), Color(0xFF126CA8)],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x88000000), blurRadius: 8),
                ],
              ),
              child: Icon(
                Icons.spa,
                color: gold ? const Color(0xFF6C3E05) : Colors.white,
                size: size * 0.45,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MainPlayButton extends StatefulWidget {
  const _MainPlayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_MainPlayButton> createState() => _MainPlayButtonState();
}

class _MainPlayButtonState extends State<_MainPlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Chơi ngay',
      child: GestureDetector(
        onTap: () {
          GameAudio.tap();
          widget.onPressed();
        },
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return AnimatedScale(
              scale: _pressed ? 0.965 : 1 + (_pulseController.value * 0.018),
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOutBack,
              child: child,
            );
          },
          child: SizedBox(
            width: 610,
            height: 154,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  left: 58,
                  right: 58,
                  bottom: 10,
                  height: 38,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0xAA000000),
                          blurRadius: 36,
                          offset: Offset(0, 14),
                        ),
                        BoxShadow(
                          color: Color(0xCCFEC04D),
                          blurRadius: 34,
                          spreadRadius: -8,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 28,
                  height: 104,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Color(0xFFFFF7A8),
                          Color(0xFFFFC43E),
                          Color(0xFFE77514),
                        ],
                        stops: <double>[0, 0.48, 1],
                      ),
                      border: Border.all(
                        color: const Color(0xFFFFF0B6),
                        width: 5,
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x99000000),
                          blurRadius: 26,
                          offset: Offset(0, 15),
                        ),
                        BoxShadow(
                          color: Color(0x99FFCF55),
                          blurRadius: 36,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 25,
                  right: 25,
                  top: 43,
                  height: 72,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[Color(0xFFFFF9D7), Color(0xFFFFB320)],
                      ),
                      border: Border.all(
                        color: const Color(0xFF9D4E02),
                        width: 3,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 54,
                  right: 54,
                  top: 54,
                  height: 18,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withValues(alpha: 0.58),
                    ),
                  ),
                ),
                Positioned(
                  left: -8,
                  child: _ButtonMedallion(
                    icon: Icons.auto_awesome_rounded,
                    color: const Color(0xFFFFDF6F),
                  ),
                ),
                Positioned(
                  right: -8,
                  child: _ButtonMedallion(
                    icon: Icons.play_arrow_rounded,
                    color: const Color(0xFFFF6E91),
                  ),
                ),
                const Positioned(
                  top: 54,
                  child: _CasinoButtonText(
                    text: 'CHƠI NGAY',
                    fontSize: 48,
                    letterSpacing: 1.4,
                    strokeWidth: 6.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatefulWidget {
  const _SecondaryActionButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  State<_SecondaryActionButton> createState() => _SecondaryActionButtonState();
}

class _SecondaryActionButtonState extends State<_SecondaryActionButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool active = _hovered || _pressed;
    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () {
            GameAudio.tap();
            widget.onPressed();
          },
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed
                ? 0.965
                : active
                ? 1.035
                : 1,
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, active ? -5 : 0, 0),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned(
                    left: 26,
                    right: 26,
                    bottom: 8,
                    height: 24,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: const Color(
                              0xFF000000,
                            ).withValues(alpha: 0.62),
                            blurRadius: active ? 26 : 18,
                            offset: Offset(0, active ? 12 : 8),
                          ),
                          BoxShadow(
                            color: const Color(
                              0xFF00F5D4,
                            ).withValues(alpha: active ? 0.28 : 0.12),
                            blurRadius: active ? 26 : 16,
                            spreadRadius: -5,
                          ),
                        ],
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Color(0xFF0B777B),
                          Color(0xFF10B7A7),
                          Color(0xFFE7B84A),
                        ],
                        stops: <double>[0, 0.58, 1],
                      ),
                      border: Border.all(
                        color: const Color(0xFFEFFFD8),
                        width: 3,
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x6600FFF0),
                          blurRadius: 18,
                          spreadRadius: -4,
                        ),
                        BoxShadow(
                          color: Color(0x99000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(
                                Radius.circular(31),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Color(0x44FFFFFF),
                                  Color(0x00000000),
                                  Color(0x33000000),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 18,
                          top: 14,
                          bottom: 14,
                          child: _ButtonMedallion(
                            icon: widget.icon,
                            color: const Color(0xFF6BF2FF),
                            compact: true,
                          ),
                        ),
                        Positioned(
                          left: 104,
                          right: 24,
                          top: 17,
                          bottom: 13,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _CasinoButtonText(
                                text: widget.label.toUpperCase(),
                                fontSize: 29,
                                letterSpacing: 0.7,
                                strokeWidth: 4.2,
                                compact: true,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.subtitle.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(
                                    0xFFFFF2BE,
                                  ).withValues(alpha: 0.96),
                                  fontFamily: 'Baloo2',
                                  fontSize: 17,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.7,
                                  shadows: const <Shadow>[
                                    Shadow(
                                      color: Color(0x99002D30),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CasinoButtonText extends StatelessWidget {
  const _CasinoButtonText({
    required this.text,
    required this.fontSize,
    required this.letterSpacing,
    required this.strokeWidth,
    this.compact = false,
  });

  final String text;
  final double fontSize;
  final double letterSpacing;
  final double strokeWidth;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final TextStyle baseStyle = TextStyle(
      fontFamily: 'Baloo2',
      fontSize: fontSize,
      height: compact ? 0.9 : 0.84,
      fontWeight: FontWeight.w900,
      letterSpacing: letterSpacing,
    );
    final Rect shaderBounds = Rect.fromLTWH(
      0,
      0,
      fontSize * text.length * 0.78,
      fontSize * 1.28,
    );

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: <Widget>[
        Transform.translate(
          offset: Offset(0, compact ? 4 : 6),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: baseStyle.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = strokeWidth + 3
                ..color = const Color(0x99000000),
            ),
          ),
        ),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.visible,
          style: baseStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = const Color(0xFF7A3300),
          ),
        ),
        Transform.translate(
          offset: Offset(0, compact ? -1 : -2),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: baseStyle.copyWith(
              foreground: Paint()
                ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0xFFFFFFFF),
                    Color(0xFFFFF0A7),
                    Color(0xFFFFB531),
                    Color(0xFFE56A00),
                  ],
                  stops: <double>[0, 0.34, 0.7, 1],
                ).createShader(shaderBounds),
              shadows: const <Shadow>[
                Shadow(
                  color: Color(0xFFFFE37A),
                  blurRadius: 8,
                  offset: Offset(0, -1),
                ),
                Shadow(
                  color: Color(0xAA000000),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ButtonMedallion extends StatelessWidget {
  const _ButtonMedallion({
    required this.icon,
    required this.color,
    this.compact = false,
  });

  final IconData icon;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 70 : 92;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white,
            color,
            Color.lerp(color, Colors.black, 0.34)!,
          ],
          stops: const <double>[0, 0.48, 1],
        ),
        border: Border.all(color: const Color(0xFFFFF8D4), width: 3),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.55),
            blurRadius: compact ? 18 : 24,
          ),
          const BoxShadow(
            color: Color(0x99000000),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: const Color(0xFF5C3303),
        size: compact ? 36 : 48,
      ),
    );
  }
}
