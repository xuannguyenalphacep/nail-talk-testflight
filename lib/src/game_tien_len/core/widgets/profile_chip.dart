import 'package:flutter/material.dart';

import '../theme/game_theme.dart';

class ProfileChip extends StatelessWidget {
  const ProfileChip({required this.name, required this.balance, super.key});

  final String name;
  final int balance;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xB8062031),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x8838DFFF)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0xAA000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
          BoxShadow(color: Color(0x5538DFFF), blurRadius: 16),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 7, 16, 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Color(0xFFFFE4A6),
                        Color(0xFF1FC7FF),
                        Color(0xFF082133),
                      ],
                    ),
                    border: Border.all(color: GameTheme.gold, width: 2),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
                Positioned(
                  left: -2,
                  bottom: -7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFFFFE29A), Color(0xFFE8A923)],
                      ),
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(color: Color(0x88000000), blurRadius: 6),
                      ],
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      child: Text(
                        'VIP 3',
                        style: TextStyle(
                          color: GameTheme.ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 13),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  name,
                  style: const TextStyle(
                    color: GameTheme.ivory,
                    fontSize: 14,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.monetization_on,
                      color: GameTheme.gold,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      balance.toString(),
                      style: const TextStyle(
                        color: Color(0xFFFFD978),
                        fontSize: 12,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 78,
                      height: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0x55000000),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 0.72,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  Color(0xFF55E7FF),
                                  Color(0xFF72FFB6),
                                ],
                              ),
                              borderRadius: BorderRadius.all(
                                Radius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
