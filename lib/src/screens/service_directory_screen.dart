import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/social_hub_controller.dart';
import '../core/localization/app_localizer.dart';
import '../models/service_category.dart';
import '../widgets/metro_ui.dart';
import '../widgets/remote_image.dart';
import 'clinic_finder_screen.dart';

const Color _serviceInk = Color(0xFF17395F);
const Color _serviceTeal = Color(0xFF0F9D96);
const Color _servicePink = Color(0xFFD669A4);

class ServiceDirectoryScreen extends StatefulWidget {
  const ServiceDirectoryScreen({super.key});

  @override
  State<ServiceDirectoryScreen> createState() => _ServiceDirectoryScreenState();
}

class _ServiceDirectoryScreenState extends State<ServiceDirectoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SocialHubController>().refreshServices();
    });
  }

  Future<void> _refresh() {
    return context.read<SocialHubController>().refreshServices();
  }

  Future<void> _openService(ServiceCategory service) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ClinicFinderScreen(service: service)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SocialHubController>();
    final services = controller.serviceCategories;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MetroPageBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              children: [
                _ServiceHeader(onBack: () => Navigator.of(context).maybePop()),
                const SizedBox(height: 18),
                const _ServiceHeroBanner(),
                if (controller.loadingServices) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: const LinearProgressIndicator(minHeight: 4),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  context.tr('Choose a service'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _serviceInk,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                if (services.isEmpty && !controller.loadingServices)
                  _EmptyServices(onRetry: _refresh)
                else
                  ...services.map(
                    (service) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _ServiceCard(
                        service: service,
                        onTap: () => _openService(service),
                      ),
                    ),
                  ),
                const SizedBox(height: 88),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceHeader extends StatelessWidget {
  const _ServiceHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MetroActionButton(
          icon: Icons.arrow_back_ios_new_rounded,
          label: 'Back',
          onPressed: onBack,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            context.tr('Services'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: _serviceInk,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _ServiceHeroBanner extends StatelessWidget {
  const _ServiceHeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/branding/vietnam_clinic_banner_bg.png',
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xEE0A7F84),
                  Color(0xAA219BA0),
                  Color(0x22159BA0),
                ],
                stops: [0, 0.62, 1],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ServiceChip(
                  label: 'Services',
                  icon: Icons.room_service_rounded,
                  color: Colors.white,
                  foreground: _serviceInk,
                ),
                const Spacer(),
                SizedBox(
                  width: 270,
                  child: Text(
                    context.tr('Book trusted services in Vietnam'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontSize: 25,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  width: 280,
                  child: Text(
                    context.tr(
                      'Choose spa, beauty, and linked service partners before traveling.',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.96),
                      height: 1.25,
                      fontWeight: FontWeight.w800,
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

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.onTap});

  final ServiceCategory service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = _serviceColor(service);
    final count = service.providersCount;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE5EEF0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 132,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    service.bannerImageUrl.trim().isEmpty
                        ? Image.asset(
                            'assets/branding/vietnam_clinic_banner_bg.png',
                            fit: BoxFit.cover,
                            alignment: Alignment.centerRight,
                          )
                        : RemoteImage(
                            url: service.bannerImageUrl,
                            width: double.infinity,
                            height: 132,
                            errorFallback: Image.asset(
                              'assets/branding/vietnam_clinic_banner_bg.png',
                              fit: BoxFit.cover,
                              alignment: Alignment.centerRight,
                            ),
                          ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            tint.withValues(alpha: 0.88),
                            tint.withValues(alpha: 0.42),
                            Colors.transparent,
                          ],
                          stops: const [0, 0.58, 1],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: _ServiceChip(
                          label: _reviewSafeServiceText(
                            context,
                            service.shortLabel.trim().isEmpty
                                ? service.name
                                : service.shortLabel,
                          ),
                          icon: _serviceIcon(service),
                          color: Colors.white,
                          foreground: _serviceInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _reviewSafeServiceText(context, service.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: _serviceInk,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _reviewSafeServiceText(
                            context,
                            service.displaySummary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: kMetroMuted,
                                height: 1.28,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(height: 10),
                          _CountPill(count: count),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: tint,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: tint.withValues(alpha: 0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(11),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyServices extends StatelessWidget {
  const _EmptyServices({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5EEF0)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.room_service_outlined,
            color: _serviceTeal,
            size: 42,
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('No services found yet'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _serviceInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('Services will appear here after admin publishes them.'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: kMetroMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: metroSoftOutlinedButtonStyle(context),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(context.tr('Refresh')),
          ),
        ],
      ),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.foreground,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 6),
          Text(
            context.tr(label),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.tr('{count} linked partners', {'count': '$count'}),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: _serviceInk,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

IconData _serviceIcon(ServiceCategory service) {
  return switch (service.icon.trim().toLowerCase()) {
    'spa' || 'beauty' => Icons.spa_rounded,
    'clinic' || 'hospital' || 'health' => Icons.spa_rounded,
    'travel' => Icons.flight_takeoff_rounded,
    _ => Icons.room_service_rounded,
  };
}

Color _serviceColor(ServiceCategory service) {
  final raw = service.tintColor.trim().replaceFirst('#', '');
  if (raw.length == 6) {
    final value = int.tryParse('FF$raw', radix: 16);
    if (value != null) return Color(value);
  }
  return service.slug == 'spa' ? _servicePink : _serviceTeal;
}

String _reviewSafeServiceText(BuildContext context, String raw) {
  final translated = context.tr(raw);
  return translated
      .replaceAll(
        RegExp(r'\bclinics?\b', caseSensitive: false),
        'service partners',
      )
      .replaceAll(
        RegExp(r'\bhospitals?\b', caseSensitive: false),
        'beauty partners',
      )
      .replaceAll(
        RegExp(r'\bhealthcare\b', caseSensitive: false),
        'beauty services',
      )
      .replaceAll(
        RegExp(r'phòng khám', caseSensitive: false),
        'đối tác dịch vụ',
      )
      .replaceAll(RegExp(r'bệnh viện', caseSensitive: false), 'đối tác làm đẹp')
      .replaceAll(RegExp(r'y tế', caseSensitive: false), 'dịch vụ làm đẹp')
      .replaceAll(RegExp(r'chuyên khoa', caseSensitive: false), 'dịch vụ');
}
