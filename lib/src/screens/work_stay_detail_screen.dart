import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/social_hub_controller.dart';
import '../core/localization/app_localizer.dart';
import '../core/utils/app_date_utils.dart';
import '../models/job_listing_item.dart';
import '../models/property_listing_item.dart';
import '../widgets/metro_ui.dart';
import '../widgets/remote_image.dart';

class JobListingDetailScreen extends StatefulWidget {
  const JobListingDetailScreen({
    required this.item,
    required this.onContact,
    super.key,
  });

  final JobListingItem item;
  final Future<void> Function(JobListingItem item) onContact;

  @override
  State<JobListingDetailScreen> createState() => _JobListingDetailScreenState();
}

class _JobListingDetailScreenState extends State<JobListingDetailScreen> {
  late final PageController _pageController;
  int _imageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  JobListingItem _resolveCurrentItem(SocialHubController controller) {
    for (final item in controller.jobItems) {
      if (item.id == widget.item.id) {
        return item;
      }
    }
    return widget.item;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SocialHubController>();
    final item = _resolveCurrentItem(controller);
    final imageUrls = item.imageUrls.isEmpty ? const [''] : item.imageUrls;
    final safeIndex = _imageIndex.clamp(0, imageUrls.length - 1);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Text(
          context.tr(item.title),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: MetroPageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            MetroInsetPanel(
              borderColor: kMetroGold,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailGallery(
                    imageUrls: imageUrls,
                    safeIndex: safeIndex,
                    pageController: _pageController,
                    onPageChanged: (index) {
                      setState(() => _imageIndex = index);
                    },
                    onThumbTap: (index) {
                      setState(() => _imageIndex = index);
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    badges: [
                      MetroBadge(label: _jobModeLabel(item.listingMode)),
                      if (item.salonName.isNotEmpty)
                        MetroBadge(
                          label: item.salonName,
                          backgroundColor: Colors.white.withValues(alpha: 0.9),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(item.title),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: kMetroInk, fontSize: 30),
                        ),
                        const SizedBox(height: 8),
                        if (_salary(item).isNotEmpty)
                          Text(
                            _salary(item),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: kMetroGold,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (_location(item.city, item.state).isNotEmpty)
                              MetroBadge(
                                label: _location(item.city, item.state),
                                backgroundColor: const Color(0xFFF0F3FA),
                              ),
                            if (item.status.isNotEmpty)
                              MetroBadge(
                                label: _workStayStatusLabel(item.status),
                                backgroundColor: const Color(0xFFEFF8F2),
                              ),
                            if (item.userName.isNotEmpty)
                              MetroBadge(
                                label: item.userName,
                                backgroundColor: const Color(0xFFFFEEF2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => widget.onContact(item),
                          child: Text(
                            context.tr(
                              item.listingMode == 'looking_for_job'
                                  ? 'Message candidate'
                                  : 'Chat recruiter',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            MetroInsetPanel(
              borderColor: kMetroGold,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('About this role'),
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: kMetroInk),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr(item.description),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: kMetroMuted),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.tr('Requirements'),
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: kMetroInk),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr(
                      item.requirements.trim().isEmpty
                          ? 'No specific requirements listed yet.'
                          : item.requirements,
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: kMetroMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MetroInsetPanel(
              borderColor: kMetroPrimary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Recruiter info'),
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: kMetroInk),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: 'Name',
                    value: item.userName.isEmpty ? '...' : item.userName,
                  ),
                  if (item.salonName.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _DetailRow(label: 'Salon Name', value: item.salonName),
                  ],
                  if (_location(item.city, item.state).isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _DetailRow(
                      label: 'State',
                      value: _location(item.city, item.state),
                    ),
                  ],
                  if (item.contactPhone.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _DetailRow(label: 'Phone', value: item.contactPhone),
                  ],
                  if (item.contactEmail.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _DetailRow(label: 'Email', value: item.contactEmail),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PropertyListingDetailScreen extends StatefulWidget {
  const PropertyListingDetailScreen({
    required this.item,
    required this.onContact,
    super.key,
  });

  final PropertyListingItem item;
  final Future<void> Function(PropertyListingItem item) onContact;

  @override
  State<PropertyListingDetailScreen> createState() =>
      _PropertyListingDetailScreenState();
}

class _PropertyListingDetailScreenState
    extends State<PropertyListingDetailScreen> {
  late final PageController _pageController;
  int _imageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  PropertyListingItem _resolveCurrentItem(SocialHubController controller) {
    for (final item in controller.propertyItems) {
      if (item.id == widget.item.id) {
        return item;
      }
    }
    return widget.item;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SocialHubController>();
    final item = _resolveCurrentItem(controller);
    final imageUrls = item.imageUrls.isEmpty ? const [''] : item.imageUrls;
    final safeIndex = _imageIndex.clamp(0, imageUrls.length - 1);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Text(
          context.tr(item.title),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: MetroPageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            MetroInsetPanel(
              borderColor: kMetroPrimary,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailGallery(
                    imageUrls: imageUrls,
                    safeIndex: safeIndex,
                    pageController: _pageController,
                    onPageChanged: (index) {
                      setState(() => _imageIndex = index);
                    },
                    onThumbTap: (index) {
                      setState(() => _imageIndex = index);
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    badges: [
                      MetroBadge(label: _propertyModeLabel(item.listingMode)),
                      if (item.amenities.isNotEmpty)
                        MetroBadge(
                          label: item.amenities.first,
                          backgroundColor: Colors.white.withValues(alpha: 0.9),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(item.title),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: kMetroInk, fontSize: 30),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _money(item.price, item.currency),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: kMetroPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (_location(item.city, item.state).isNotEmpty)
                              MetroBadge(
                                label: _location(item.city, item.state),
                                backgroundColor: const Color(0xFFF0F3FA),
                              ),
                            if (item.status.isNotEmpty)
                              MetroBadge(
                                label: _workStayStatusLabel(item.status),
                                backgroundColor: const Color(0xFFEFF8F2),
                              ),
                            if (item.userName.isNotEmpty)
                              MetroBadge(
                                label: item.userName,
                                backgroundColor: const Color(0xFFFFEEF2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => widget.onContact(item),
                          child: Text(
                            context.tr(
                              item.listingMode == 'looking_room'
                                  ? 'Message renter'
                                  : 'Chat host',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            MetroInsetPanel(
              borderColor: kMetroPrimary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('About this place'),
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: kMetroInk),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr(item.description),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: kMetroMuted),
                  ),
                  if (item.addressLine.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _DetailRow(label: 'Address', value: item.addressLine),
                  ],
                  if (item.availableFrom != null) ...[
                    const SizedBox(height: 10),
                    _DetailRow(
                      label: 'Available from',
                      value: AppDateUtils.formatDate(item.availableFrom),
                    ),
                  ],
                  if (item.depositAmount != null) ...[
                    const SizedBox(height: 10),
                    _DetailRow(
                      label: 'Deposit',
                      value: _money(item.depositAmount!, item.currency),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            MetroInsetPanel(
              borderColor: kMetroGold,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Housing details'),
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: kMetroInk),
                  ),
                  const SizedBox(height: 12),
                  if (item.amenities.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: item.amenities
                          .map(
                            (amenity) => MetroBadge(
                              label: amenity,
                              backgroundColor: const Color(0xFFF0F3FA),
                            ),
                          )
                          .toList(),
                    )
                  else
                    Text(
                      context.tr('No extra housing notes yet.'),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: kMetroMuted),
                    ),
                  const SizedBox(height: 14),
                  _DetailRow(
                    label: 'Name',
                    value: item.userName.isEmpty ? '...' : item.userName,
                  ),
                  if (item.contactPhone.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _DetailRow(label: 'Phone', value: item.contactPhone),
                  ],
                  if (item.contactEmail.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _DetailRow(label: 'Email', value: item.contactEmail),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailGallery extends StatelessWidget {
  const _DetailGallery({
    required this.imageUrls,
    required this.safeIndex,
    required this.pageController,
    required this.onPageChanged,
    required this.onThumbTap,
    required this.badges,
  });

  final List<String> imageUrls;
  final int safeIndex;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onThumbTap;
  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.22,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kMetroRadius),
            child: Stack(
              children: [
                PageView.builder(
                  controller: pageController,
                  itemCount: imageUrls.length,
                  onPageChanged: onPageChanged,
                  itemBuilder: (context, index) {
                    final url = imageUrls[index];
                    if (url.trim().isEmpty) {
                      return const _DetailFallbackArt();
                    }
                    return RemoteImage(
                      url: url,
                      fit: BoxFit.cover,
                      errorFallback: const _DetailFallbackArt(),
                    );
                  },
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Wrap(spacing: 8, runSpacing: 8, children: badges),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: MetroBadge(
                    label: '${safeIndex + 1}/${imageUrls.length}',
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (imageUrls.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: imageUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final selected = safeIndex == index;
                  return GestureDetector(
                    onTap: () => onThumbTap(index),
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selected ? kMetroCoral : kMetroLine,
                          width: selected ? 1.6 : 1,
                        ),
                        borderRadius: BorderRadius.circular(kMetroRadius),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: imageUrls[index].trim().isEmpty
                          ? const _DetailFallbackArt()
                          : RemoteImage(
                              url: imageUrls[index],
                              fit: BoxFit.cover,
                              errorFallback: const _DetailFallbackArt(),
                            ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            context.tr(label),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: kMetroMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: kMetroInk),
          ),
        ),
      ],
    );
  }
}

class _DetailFallbackArt extends StatelessWidget {
  const _DetailFallbackArt();

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
      child: const Center(
        child: Icon(
          Icons.apartment_rounded,
          size: 44,
          color: Color(0xFF27366E),
        ),
      ),
    );
  }
}

String _jobModeLabel(String mode) {
  switch (mode) {
    case 'looking_for_job':
      return 'Job seekers';
    case 'hiring':
    default:
      return 'Hiring nail staff';
  }
}

String _propertyModeLabel(String mode) {
  switch (mode) {
    case 'rent_out':
      return 'Homes for rent';
    case 'looking_room':
      return 'Looking for a room';
    case 'room_share':
    default:
      return 'Room share';
  }
}

String _workStayStatusLabel(String status) {
  switch (status.trim().toLowerCase()) {
    case 'published':
      return 'Published';
    case 'draft':
      return 'Draft';
    case 'pending':
      return 'Pending';
    case 'active':
      return 'Active';
    case 'inactive':
      return 'Inactive';
    default:
      return _humanize(status);
  }
}

String _humanize(String raw) {
  final cleaned = raw.replaceAll('_', ' ').replaceAll('-', ' ').trim();
  if (cleaned.isEmpty) return '';

  return cleaned
      .split(RegExp(r'\s+'))
      .map((word) {
        final lower = word.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

String _location(String city, String state) {
  final parts = <String>[
    if (city.trim().isNotEmpty) city.trim(),
    if (state.trim().isNotEmpty) state.trim(),
  ];
  return parts.join(', ');
}

String _money(double value, String currency) {
  final prefix = currency.toUpperCase() == 'USD'
      ? '\$'
      : '${currency.toUpperCase()} ';
  final isWhole = value == value.roundToDouble();
  return '$prefix${value.toStringAsFixed(isWhole ? 0 : 2)}';
}

String _salary(JobListingItem item) {
  if (item.salaryMin != null && item.salaryMax != null) {
    return '${_money(item.salaryMin!, item.salaryCurrency)} - ${_money(item.salaryMax!, item.salaryCurrency)}';
  }
  if (item.salaryMin != null) {
    return AppLocalizer.current.tr('From {amount}', {
      'amount': _money(item.salaryMin!, item.salaryCurrency),
    });
  }
  if (item.salaryMax != null) {
    return AppLocalizer.current.tr('Up to {amount}', {
      'amount': _money(item.salaryMax!, item.salaryCurrency),
    });
  }
  return '';
}
