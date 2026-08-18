import 'package:flutter/material.dart';

import '../core/localization/app_localizer.dart';
import 'remote_image.dart';

const double kMetroRadius = 24;
const Color kMetroCanvas = Color(0xFFFFFCFA);
const Color kMetroCanvasDeep = Color(0xFFFFF2EC);
const Color kMetroSurface = Color(0xFFFFFFFF);
const Color kMetroPrimary = Color(0xFF27366E);
const Color kMetroPrimarySoft = Color(0xFFF1F4FF);
const Color kMetroInk = Color(0xFF243053);
const Color kMetroMuted = Color(0xFF7D87A7);
const Color kMetroLine = Color(0xFFF2E8E3);
const Color kMetroCoral = Color(0xFFFF5E88);
const Color kMetroCoralSoft = Color(0xFFFFF0F4);
const Color kMetroRose = Color(0xFFE56A93);
const Color kMetroPeach = Color(0xFFFFE8DD);
const Color kMetroGold = Color(0xFFF2BC62);
const Color kMetroSuccess = Color(0xFF68C279);

InputDecoration metroSoftInputDecoration(
  BuildContext context, {
  required String hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? labelText,
  String? helperText,
}) {
  OutlineInputBorder border(Color color, {double width = 1.1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    hintText: context.tr(hintText),
    labelText: labelText == null ? null : context.tr(labelText),
    helperText: helperText == null ? null : context.tr(helperText),
    filled: true,
    fillColor: const Color(0xFFFFFBF8),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: const Color(0xFF9298AD),
      fontWeight: FontWeight.w600,
    ),
    labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: kMetroMuted,
      fontWeight: FontWeight.w800,
    ),
    helperStyle: Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: kMetroMuted),
    border: border(const Color(0xFFE9DDD6)),
    enabledBorder: border(const Color(0xFFE9DDD6)),
    focusedBorder: border(kMetroCoral.withValues(alpha: 0.74), width: 1.35),
    errorBorder: border(const Color(0xFFD15D6F), width: 1.2),
    focusedErrorBorder: border(const Color(0xFFD15D6F), width: 1.3),
  );
}

ButtonStyle metroSoftOutlinedButtonStyle(BuildContext context) {
  return OutlinedButton.styleFrom(
    foregroundColor: kMetroPrimary,
    backgroundColor: Colors.white.withValues(alpha: 0.94),
    side: const BorderSide(color: Color(0xFFE7DDD7)),
    minimumSize: const Size(0, 46),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
  );
}

ButtonStyle metroSoftFilledButtonStyle(BuildContext context, Color accent) {
  final background = Color.alphaBlend(
    Colors.white.withValues(alpha: 0.18),
    accent,
  );

  return FilledButton.styleFrom(
    backgroundColor: background,
    foregroundColor: Colors.white,
    disabledBackgroundColor: background.withValues(alpha: 0.48),
    minimumSize: const Size(0, 46),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
  );
}

class MetroPageBackground extends StatelessWidget {
  const MetroPageBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kMetroCanvas, Color(0xFFFFF7F1), kMetroCanvasDeep],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -28,
            right: -18,
            child: _MetroBackdropOrb(
              width: 220,
              height: 220,
              colors: [Color(0x1AFAB5C4), Color(0x00FFFFFF)],
            ),
          ),
          const Positioned(
            top: 120,
            left: -34,
            child: _MetroBackdropOrb(
              width: 150,
              height: 210,
              colors: [Color(0x15F5D3C8), Color(0x00FFFFFF)],
            ),
          ),
          const Positioned(
            bottom: 96,
            right: 8,
            child: _MetroBackdropOrb(
              width: 170,
              height: 170,
              colors: [Color(0x12BFD4FF), Color(0x00FFFFFF)],
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kMetroLine),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 16,
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
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
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
        color: backgroundColor.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor.withValues(alpha: 0.22)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
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
      borderRadius: BorderRadius.circular(24),
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
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
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.14),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
          const BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(28),
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
            borderRadius: BorderRadius.circular(14),
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor.withValues(alpha: 0.22)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 10),
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
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(28),
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
                borderRadius: BorderRadius.circular(24),
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
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetroBackdropOrb extends StatelessWidget {
  const _MetroBackdropOrb({
    required this.width,
    required this.height,
    required this.colors,
  });

  final double width;
  final double height;
  final List<Color> colors;

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
          borderRadius: BorderRadius.circular(width / 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
      ),
    );
  }
}
