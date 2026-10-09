import 'package:flutter/material.dart';

import '../../features/tien_len/data/game_data.dart';
import '../theme/game_theme.dart';

class PlayingCardView extends StatelessWidget {
  const PlayingCardView({
    required this.card,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final PlayingCardData card;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color foreground = card.suit.isRed
        ? const Color(0xFFBE2534)
        : const Color(0xFF111A24);
    final Color glowColor = card.suit.isRed
        ? const Color(0xFFFF6B7B)
        : const Color(0xFF46DAFF);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, selected ? -16 : 0, 0),
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: <BoxShadow>[
            const BoxShadow(
              color: Color(0xAA000000),
              blurRadius: 12,
              offset: Offset(0, 7),
            ),
            if (selected)
              BoxShadow(
                color: glowColor.withValues(alpha: 0.62),
                blurRadius: 22,
                spreadRadius: 2,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFFFFFFFF),
                  Color(0xFFFFF6DF),
                  Color(0xFFE6F8FF),
                ],
              ),
              border: Border.all(
                color: selected ? GameTheme.gold : const Color(0xFFE9D9B6),
                width: selected ? 3 : 1.2,
              ),
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  right: -18,
                  bottom: -18,
                  child: Icon(
                    _suitIcon(card.suit),
                    color: foreground.withValues(alpha: 0.08),
                    size: 92,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            card.rank,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              height: 0.92,
                            ),
                          ),
                          const SizedBox(height: 4),
                          CustomPaint(
                            size: const Size(42, 40),
                            painter: _SuitPainter(
                              suit: card.suit,
                              color: foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _CardCorner(
                  rank: card.rank,
                  suit: card.suit,
                  color: foreground,
                  alignment: Alignment.topLeft,
                ),
                RotatedBox(
                  quarterTurns: 2,
                  child: _CardCorner(
                    rank: card.rank,
                    suit: card.suit,
                    color: foreground,
                    alignment: Alignment.topLeft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _suitIcon(CardSuit suit) {
    return switch (suit) {
      CardSuit.clubs => Icons.filter_vintage,
      CardSuit.diamonds => Icons.diamond,
      CardSuit.hearts => Icons.favorite,
      CardSuit.spades => Icons.spa,
    };
  }
}

class _CardCorner extends StatelessWidget {
  const _CardCorner({
    required this.rank,
    required this.suit,
    required this.color,
    required this.alignment,
  });

  final String rank;
  final CardSuit suit;
  final Color color;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.only(left: 7, top: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              rank,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                height: 0.9,
              ),
            ),
            Text(
              suit.symbol,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 0.9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuitPainter extends CustomPainter {
  const _SuitPainter({required this.suit, required this.color});

  final CardSuit suit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final Path path = Path();

    switch (suit) {
      case CardSuit.diamonds:
        path
          ..moveTo(centerX, 2)
          ..lineTo(size.width - 3, centerY)
          ..lineTo(centerX, size.height - 2)
          ..lineTo(3, centerY)
          ..close();
        canvas.drawPath(path, paint);
      case CardSuit.hearts:
        path
          ..moveTo(centerX, size.height - 2)
          ..cubicTo(1, centerY + 4, 1, 9, 11, 7)
          ..cubicTo(16, 5, centerX - 2, 11, centerX, 14)
          ..cubicTo(centerX + 2, 11, 26, 5, 31, 7)
          ..cubicTo(41, 9, 41, centerY + 4, centerX, size.height - 2)
          ..close();
        canvas.drawPath(path, paint);
      case CardSuit.spades:
        path
          ..moveTo(centerX, 2)
          ..cubicTo(41, centerY - 4, 39, centerY + 8, 31, centerY + 11)
          ..lineTo(28, size.height - 9)
          ..lineTo(35, size.height - 3)
          ..lineTo(7, size.height - 3)
          ..lineTo(14, size.height - 9)
          ..lineTo(11, centerY + 11)
          ..cubicTo(3, centerY + 8, 1, centerY - 4, centerX, 2)
          ..close();
        canvas.drawPath(path, paint);
      case CardSuit.clubs:
        canvas
          ..drawCircle(Offset(centerX - 9, 17), 8, paint)
          ..drawCircle(Offset(centerX, 9), 8, paint)
          ..drawCircle(Offset(centerX + 9, 17), 8, paint);
        path
          ..moveTo(centerX - 5, 17)
          ..lineTo(centerX + 5, 17)
          ..lineTo(centerX + 4, size.height - 7)
          ..lineTo(centerX + 11, size.height - 2)
          ..lineTo(centerX - 11, size.height - 2)
          ..lineTo(centerX - 4, size.height - 7)
          ..close();
        canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SuitPainter oldDelegate) {
    return oldDelegate.suit != suit || oldDelegate.color != color;
  }
}

class CardBackView extends StatelessWidget {
  const CardBackView({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x88000000),
            blurRadius: 8,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(
              'assets/game_tien_len/cards/card_back.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0x5538DFFF),
                    Color(0x00000000),
                    Color(0x55FFD36E),
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
