import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 56, this.showWordmark = true});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    if (showWordmark) {
      return Image.asset(
        'assets/branding/brand_logo.png',
        height: size,
        fit: BoxFit.contain,
        semanticLabel: 'Nail Talk',
      );
    }

    return Image.asset(
      'assets/branding/app_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'Nail Talk',
    );
  }
}
