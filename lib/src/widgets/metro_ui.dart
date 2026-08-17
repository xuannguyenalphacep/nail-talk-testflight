import 'package:flutter/material.dart';

import '../core/localization/app_localizer.dart';
import 'remote_image.dart';

const double kMetroRadius = 2;
const Color kMetroCanvas = Color(0xFFFFF7F3);
const Color kMetroCanvasDeep = Color(0xFFF7E9E2);
const Color kMetroSurface = Color(0xFFFFFCF8);
const Color kMetroPrimary = Color(0xFF27366E);
const Color kMetroPrimarySoft = Color(0xFFE8ECF8);
const Color kMetroInk = Color(0xFF243053);
const Color kMetroMuted = Color(0xFF787E92);
const Color kMetroLine = Color(0xFFE7D7CF);
const Color kMetroCoral = Color(0xFFF36C84);
const Color kMetroCoralSoft = Color(0xFFFFEEF2);
const Color kMetroRose = Color(0xFFC76883);
const Color kMetroPeach = Color(0xFFF8D7C9);
const Color kMetroGold = Color(0xFFE3B469);
const Color kMetroSuccess = Color(0xFF73A58B);

class MetroPageBackground extends StatelessWidget {
  const MetroPageBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kMetroCanvas, Color(0xFFFDF0EA), kMetroCanvasDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -22,
            right: -40,
            child: _MetroBackdropBlock(
              width: 220,
              height: 176,
              colors: [Color(0x30F7D5D0), Color(0x12FFFFFF)],
              borderColor: Color(0x26E3BBB2),
            ),
          ),
          const Positioned(
            top: 148,
            left: -28,
            child: _MetroBackdropBlock(
              width: 132,
              height: 200,
              colors: [Color(0x24F6D3C4), Color(0x0EFFFFFF)],
              borderColor: Color(0x22E8B49A),
            ),
          ),
          const Positioned(
            bottom: 92,
            right: 24,
            child: _MetroBackdropBlock(
              width: 168,
              height: 132,
              colors: [Color(0x1A35467D), Color(0x10FFFFFF)],
              borderColor: Color(0x205867A2),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _MetroGridPainter()),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class MetroActionButton extends StatelessWidget {
  const MetroActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tint = kMetroSurface,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Tooltip(
      message: context.tr(label),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(kMetroRadius),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: enabled ? tint : tint.withValues(alpha: 0.56),
            borderRadius: BorderRadius.circular(kMetroRadius),
            border: Border.all(color: kMetroLine),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A2C2143),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? kMetroInk : kMetroMuted.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class MetroSectionHeader extends StatelessWidget {
  const MetroSectionHeader({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(title),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: kMetroInk,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(subtitle),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: kMetroMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 12),
          TextButton(
            onPressed: onAction,
            child: Text(context.tr(actionLabel!)),
          ),
        ],
      ],
    );
  }
}

class MetroBadge extends StatelessWidget {
  const MetroBadge({
    required this.label,
    this.backgroundColor = const Color(0xFFF6F1E5),
    this.foregroundColor = kMetroInk,
    this.outlined = true,
    super.key,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(kMetroRadius),
        border: outlined ? Border.all(color: kMetroLine) : null,
      ),
      child: Text(
        context.tr(label),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class MetroMetricTile extends StatelessWidget {
  const MetroMetricTile({
    required this.label,
    required this.value,
    required this.borderColor,
    super.key,
  });

  final String label;
  final String value;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: kMetroSurface,
        borderRadius: BorderRadius.circular(kMetroRadius),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: kMetroInk,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr(label),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: kMetroMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class MetroImageFrame extends StatelessWidget {
  const MetroImageFrame({
    required this.child,
    required this.borderColor,
    this.imageUrl = '',
    this.onTap,
    this.height,
    this.width,
    this.padding = const EdgeInsets.all(16),
    this.overlayTop = const Color(0x1F141414),
    this.overlayBottom = const Color(0xB2141414),
    this.backgroundColor = kMetroSurface,
    this.backgroundChild,
    super.key,
  });

  final Widget child;
  final Color borderColor;
  final String imageUrl;
  final VoidCallback? onTap;
  final double? height;
  final double? width;
  final EdgeInsets padding;
  final Color overlayTop;
  final Color overlayBottom;
  final Color backgroundColor;
  final Widget? backgroundChild;

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(kMetroRadius),
      child: Stack(
        children: [
          Positioned.fill(
            child:
                backgroundChild ??
                (imageUrl.trim().isEmpty
                    ? const _MetroFallbackArt()
                    : RemoteImage(
                        url: imageUrl,
                        fit: BoxFit.cover,
                        errorFallback: const _MetroFallbackArt(),
                      )),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [overlayTop, overlayBottom],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(kMetroRadius),
        border: Border.all(color: borderColor, width: 1.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(kMetroRadius),
              child: content,
            ),
    );
  }
}

class MetroFilterChip extends StatelessWidget {
  const MetroFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accentColor = kMetroPrimary,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kMetroRadius),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? accentColor : kMetroSurface,
            borderRadius: BorderRadius.circular(kMetroRadius),
            border: Border.all(
              color: selected ? accentColor : kMetroLine,
              width: 1.2,
            ),
          ),
          child: Text(
            context.tr(label),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: selected ? Colors.white : kMetroInk,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class MetroInsetPanel extends StatelessWidget {
  const MetroInsetPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderColor = kMetroLine,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: kMetroSurface,
        borderRadius: BorderRadius.circular(kMetroRadius),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class MetroEmptyState extends StatelessWidget {
  const MetroEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.borderColor = const Color(0xFF8F99A8),
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return MetroImageFrame(
      borderColor: borderColor,
      overlayTop: const Color(0x22FFFFFF),
      overlayBottom: const Color(0xE8F5F2EA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kMetroInk, size: 28),
          const Spacer(),
          Text(
            context.tr(title),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: kMetroInk,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr(message),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: kMetroMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetroFallbackArt extends StatelessWidget {
  const _MetroFallbackArt();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF9E2DB), Color(0xFFFFEADA), Color(0xFFDDE3F2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -18,
            right: -24,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
            ),
          ),
          Positioned(
            left: 14,
            bottom: 18,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: kMetroPrimary.withValues(alpha: 0.16),
                border: Border.all(
                  color: kMetroPrimary.withValues(alpha: 0.22),
                ),
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: 24,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: kMetroCoral.withValues(alpha: 0.16),
                border: Border.all(color: kMetroCoral.withValues(alpha: 0.2)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetroBackdropBlock extends StatelessWidget {
  const _MetroBackdropBlock({
    required this.width,
    required this.height,
    required this.colors,
    required this.borderColor,
  });

  final double width;
  final double height;
  final List<Color> colors;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: borderColor),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetroGridPainter extends CustomPainter {
  const _MetroGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0ED0BEB4)
      ..strokeWidth = 1;

    const gap = 40.0;

    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
