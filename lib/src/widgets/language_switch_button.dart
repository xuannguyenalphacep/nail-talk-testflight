import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/localization/app_localizer.dart';

class LanguageSwitchButton extends StatelessWidget {
  const LanguageSwitchButton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppLocaleController>();
    final current = controller.language;

    return PopupMenuButton<AppLanguage>(
      tooltip: context.tr('Change language'),
      onSelected: (language) => controller.setLanguage(language),
      itemBuilder: (context) => [
        PopupMenuItem<AppLanguage>(
          value: AppLanguage.vi,
          child: Text(context.tr('Vietnamese')),
        ),
        PopupMenuItem<AppLanguage>(
          value: AppLanguage.en,
          child: Text(context.tr('English')),
        ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 11 : 12,
          vertical: compact ? 10 : 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(compact ? 16 : 999),
          border: Border.all(
            color: compact ? const Color(0x1F355077) : const Color(0x19355077),
          ),
          boxShadow: compact
              ? const [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.translate_rounded, size: 18),
            const SizedBox(width: 6),
            Text(
              current.shortLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
