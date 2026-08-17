import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/session_controller.dart';
import '../core/localization/app_localizer.dart';
import '../models/chat_app_model.dart';
import '../widgets/app_logo.dart';
import '../widgets/language_switch_button.dart';
import '../widgets/metro_ui.dart';

class AppPickerScreen extends StatelessWidget {
  const AppPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kMetroCanvas, Color(0xFFFFF2EC), kMetroCanvasDeep],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 920;
              if (wide) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      children: [
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
                            child: LanguageSwitchButton(),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 10,
                                  child: _BrandPanel(theme: theme),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 11,
                                  child: _AppListPanel(session: session),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      children: [
                        const Align(
                          alignment: Alignment.centerRight,
                          child: LanguageSwitchButton(compact: true),
                        ),
                        const SizedBox(height: 14),
                        _BrandPanel(theme: theme, compact: true),
                        const SizedBox(height: 16),
                        _AppListPanel(session: session, compact: true),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.theme, this.compact = false});

  final ThemeData theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kMetroPrimary, Color(0xFF46558C), kMetroCoral],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x180F1730),
              blurRadius: 26,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const AppLogo(size: 48, showWordmark: false),
            ),
            const SizedBox(height: 18),
            Text(
              context.tr('Welcome to Nails Talk'),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontSize: 28,
                height: 1.18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr(
                'Choose the local Nails Talk space before you sign in. Your selection stays saved until you sign out.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.55,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              runSpacing: 10,
              spacing: 10,
              children: [
                _FeaturePill(
                  icon: Icons.bolt_rounded,
                  label: context.tr('Real-time chat'),
                ),
                _FeaturePill(
                  icon: Icons.lock_rounded,
                  label: context.tr('Secure sign-in'),
                ),
                _FeaturePill(
                  icon: Icons.phone_iphone_rounded,
                  label: context.tr('Mobile ready'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(compact ? 22 : 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kMetroPrimary, Color(0xFF445489), kMetroCoral],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F1730),
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const AppLogo(size: 54, showWordmark: false),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            context.tr('Welcome to Nails Talk'),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontSize: compact ? 30 : 38,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.tr(
              'Pick your local Nails Talk space, then jump into jobs, movies, marketplace posts, housing leads, and live community chat.',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            runSpacing: 12,
            spacing: 12,
            children: [
              _FeaturePill(
                icon: Icons.bolt_rounded,
                label: context.tr('Real-time sync'),
              ),
              _FeaturePill(
                icon: Icons.lock_rounded,
                label: context.tr('Protected access'),
              ),
              _FeaturePill(
                icon: Icons.phone_iphone_rounded,
                label: context.tr('Phone-first design'),
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.forum_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    context.tr(
                      'Shared API and chat services keep conversations fast while the rest of Nails Talk keeps everything in one place.',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppListPanel extends StatelessWidget {
  const _AppListPanel({required this.session, this.compact = false});

  final SessionController session;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 18 : 24,
        compact ? 18 : 24,
        compact ? 18 : 24,
        compact ? 18 : 22,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: kMetroLine),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F1730),
            blurRadius: 24,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Available spaces'),
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'Choose the Nails Talk space you want to use on this device.',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          if (session.error != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kMetroCoralSoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFF2C7CF)),
              ),
              child: Text(
                session.error!,
                style: const TextStyle(
                  color: Color(0xFFB4475E),
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (session.apps.isEmpty)
            const _EmptyAppsState()
          else if (compact)
            ListView.separated(
              itemCount: session.apps.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final app = session.apps[index];
                return _ChatAppCard(app: app, compact: true);
              },
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: session.apps.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final app = session.apps[index];
                  return _ChatAppCard(app: app);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatAppCard extends StatelessWidget {
  const _ChatAppCard({required this.app, this.compact = false});

  final ChatAppModel app;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionController>();
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => session.chooseApp(app),
        child: Ink(
          padding: EdgeInsets.all(compact ? 16 : 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kMetroLine),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFFFF6F2)],
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 60 : 72,
                height: compact ? 60 : 72,
                decoration: BoxDecoration(
                  color: kMetroCoralSoft,
                  borderRadius: BorderRadius.circular(22),
                ),
                clipBehavior: Clip.antiAlias,
                child: !kIsWeb && app.logoUrl.isNotEmpty
                    ? Image.network(
                        app.logoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                              child: AppLogo(size: 36, showWordmark: false),
                            ),
                      )
                    : const Center(
                        child: AppLogo(size: 36, showWordmark: false),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            app.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: compact ? 16 : 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: kMetroCoralSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            context.tr('Local preview'),
                            style: const TextStyle(
                              color: kMetroRose,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(
                          Icons.login_rounded,
                          size: 18,
                          color: kMetroPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.tr('Open Nails Talk'),
                          style: const TextStyle(
                            color: kMetroPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAppsState extends StatelessWidget {
  const _EmptyAppsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: kMetroCoralSoft,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.apps_outlined,
                size: 42,
                color: kMetroPrimary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.tr('No apps available yet'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kMetroInk,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Add an app record in `em_chat_apps` from the admin API to publish it here.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kMetroMuted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
