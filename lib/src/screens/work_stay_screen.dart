import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/chat_controller.dart';
import '../controllers/social_hub_controller.dart';
import '../core/localization/app_localizer.dart';
import '../models/job_listing_item.dart';
import '../models/property_listing_item.dart';
import '../widgets/metro_ui.dart';
import '../widgets/us_state_dropdown_field.dart';
import 'chat_home_screen.dart';
import 'forms/job_form_screen.dart';
import 'forms/property_form_screen.dart';
import 'work_stay_detail_screen.dart';

class WorkStayScreen extends StatefulWidget {
  const WorkStayScreen({super.key});

  @override
  State<WorkStayScreen> createState() => _WorkStayScreenState();
}

class _WorkStayScreenState extends State<WorkStayScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _segment = 0;
  bool _mineOnly = false;
  String? _stateFilter;
  String? _jobMode;
  String? _propertyMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SocialHubController>().ensureUsStatesLoaded();
      context.read<SocialHubController>().refreshJobs();
      context.read<SocialHubController>().refreshProperties();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() {
    if (_segment == 0) {
      return context.read<SocialHubController>().refreshJobs(
        mine: _mineOnly,
        mode: _jobMode,
        state: _stateFilter,
        search: _searchController.text,
      );
    }
    return context.read<SocialHubController>().refreshProperties(
      mine: _mineOnly,
      mode: _propertyMode,
      state: _stateFilter,
      search: _searchController.text,
    );
  }

  Future<void> _openPrivateChat(int? userId, String unavailableMessage) async {
    if (userId == null || userId <= 0) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(context.tr(unavailableMessage)),
        ),
      );
      return;
    }

    final chat = context.read<ChatController>();
    await chat.connectIfNeeded();
    await chat.openPrivateChatByUserId(userId);
    if (!mounted) {
      return;
    }
    if (chat.activeRoom == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(chat.error ?? context.tr('Failed to start the chat.')),
        ),
      );
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ChatHomeScreen()));
  }

  Future<void> _openJobDetail(JobListingItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobListingDetailScreen(
          item: item,
          onContact: (job) => _openPrivateChat(
            job.userId,
            'This recruiter chat is not available yet.',
          ),
        ),
      ),
    );
  }

  Future<void> _openPropertyDetail(PropertyListingItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PropertyListingDetailScreen(
          item: item,
          onContact: (property) => _openPrivateChat(
            property.userId,
            'This host chat is not available yet.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SocialHubController>();
    final loading = _segment == 0
        ? controller.loadingJobs
        : controller.loadingProperties;
    final featuredJob = controller.jobItems.isNotEmpty
        ? controller.jobItems.first
        : null;
    final featuredProperty = controller.propertyItems.isNotEmpty
        ? controller.propertyItems.first
        : null;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Text(context.tr('Work & Stay')),
        actions: [
          MetroActionButton(
            icon: Icons.refresh_rounded,
            label: 'Refresh',
            onPressed: loading ? null : _refresh,
          ),
          const SizedBox(width: 16),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => _segment == 0
                  ? JobFormScreen(initialMode: _jobMode ?? 'hiring')
                  : PropertyFormScreen(
                      initialMode: _propertyMode ?? 'room_share',
                    ),
            ),
          );
          if (created == true && mounted) {
            await _refresh();
          }
        },
        icon: Icon(
          _segment == 0 ? Icons.work_outline_rounded : Icons.home_work_outlined,
        ),
        label: Text(context.tr(_segment == 0 ? 'Post Job' : 'Post Housing')),
      ),
      body: MetroPageBackground(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 92),
            children: [
              _WorkStayHero(
                title: _segment == 0 ? 'Nail Jobs' : 'Room Share',
                subtitle: _segment == 0
                    ? 'Hiring salon talent, shift openings, and job seekers in one mobile-friendly board.'
                    : 'Rental leads, room shares, and move-in posts laid out with cleaner cards.',
                imageUrl: _segment == 0
                    ? (featuredJob?.imageUrls.isNotEmpty == true
                          ? featuredJob!.imageUrls.first
                          : '')
                    : (featuredProperty?.imageUrls.isNotEmpty == true
                          ? featuredProperty!.imageUrls.first
                          : ''),
                count: _segment == 0
                    ? controller.jobItems.length
                    : controller.propertyItems.length,
                borderColor: _segment == 0 ? kMetroGold : kMetroPrimary,
                onTap: _segment == 0
                    ? (featuredJob == null
                          ? null
                          : () => _openJobDetail(featuredJob))
                    : (featuredProperty == null
                          ? null
                          : () => _openPropertyDetail(featuredProperty)),
              ),
              const SizedBox(height: 16),
              MetroSectionHeader(
                title: _segment == 0 ? 'Hiring feed' : 'Rooms and housing',
                subtitle: _segment == 0
                    ? 'Openings and candidate posts are easier to scan in this card layout.'
                    : 'Room listings and housing leads now show photo-first with details below.',
              ),
              const SizedBox(height: 12),
              MetroInsetPanel(
                borderColor: _segment == 0 ? kMetroGold : kMetroPrimary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _WorkStayFilterChipButton(
                          label: 'Nail Jobs',
                          selected: _segment == 0,
                          onTap: () {
                            setState(() => _segment = 0);
                            _refresh();
                          },
                        ),
                        _WorkStayFilterChipButton(
                          label: 'Room Share',
                          selected: _segment == 1,
                          onTap: () {
                            setState(() => _segment = 1);
                            _refresh();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _segment == 0
                          ? [
                              _ModeChip(
                                label: 'All',
                                selected: _jobMode == null,
                                onTap: () {
                                  setState(() => _jobMode = null);
                                  _refresh();
                                },
                              ),
                              _ModeChip(
                                label: 'Hiring nail staff',
                                selected: _jobMode == 'hiring',
                                onTap: () {
                                  setState(() => _jobMode = 'hiring');
                                  _refresh();
                                },
                              ),
                              _ModeChip(
                                label: 'Job seekers',
                                selected: _jobMode == 'looking_for_job',
                                onTap: () {
                                  setState(() => _jobMode = 'looking_for_job');
                                  _refresh();
                                },
                              ),
                            ]
                          : [
                              _ModeChip(
                                label: 'All',
                                selected: _propertyMode == null,
                                onTap: () {
                                  setState(() => _propertyMode = null);
                                  _refresh();
                                },
                              ),
                              _ModeChip(
                                label: 'Room share',
                                selected: _propertyMode == 'room_share',
                                onTap: () {
                                  setState(() => _propertyMode = 'room_share');
                                  _refresh();
                                },
                              ),
                              _ModeChip(
                                label: 'Homes for rent',
                                selected: _propertyMode == 'rent_out',
                                onTap: () {
                                  setState(() => _propertyMode = 'rent_out');
                                  _refresh();
                                },
                              ),
                              _ModeChip(
                                label: 'Looking for a room',
                                selected: _propertyMode == 'looking_room',
                                onTap: () {
                                  setState(
                                    () => _propertyMode = 'looking_room',
                                  );
                                  _refresh();
                                },
                              ),
                            ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: context.tr(
                          _segment == 0
                              ? 'Search jobs'
                              : 'Search room listings',
                        ),
                        suffixIcon: IconButton(
                          onPressed: _refresh,
                          icon: const Icon(Icons.search_rounded),
                        ),
                      ),
                      onSubmitted: (_) => _refresh(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: UsStateDropdownField(
                            states: controller.usStates,
                            value: _stateFilter,
                            required: false,
                            loading: controller.loadingUsStates,
                            onChanged: (value) {
                              setState(() => _stateFilter = value);
                              _refresh();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        _WorkStayFilterChipButton(
                          label: 'My posts',
                          selected: _mineOnly,
                          onTap: () {
                            setState(() => _mineOnly = !_mineOnly);
                            _refresh();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_segment == 0) ...[
                if (controller.loadingJobs && controller.jobItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (controller.jobItems.isEmpty)
                  const SizedBox(
                    height: 210,
                    child: MetroEmptyState(
                      icon: Icons.work_outline_rounded,
                      title: 'No hiring posts yet',
                      message:
                          'New openings will show here as soon as recruiters and salon owners publish them.',
                      borderColor: Color(0xFFE0C137),
                    ),
                  )
                else
                  ...List<Widget>.generate(controller.jobItems.length, (index) {
                    final item = controller.jobItems[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _JobEditorialTile(
                        item: item,
                        borderColor: _jobTileColor(index),
                        onContact: () => _openPrivateChat(
                          item.userId,
                          'This recruiter chat is not available yet.',
                        ),
                        onOpen: () => _openJobDetail(item),
                      ),
                    );
                  }),
              ] else ...[
                if (controller.loadingProperties &&
                    controller.propertyItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (controller.propertyItems.isEmpty)
                  const SizedBox(
                    height: 210,
                    child: MetroEmptyState(
                      icon: Icons.home_work_outlined,
                      title: 'No housing posts yet',
                      message:
                          'New room shares and housing posts will surface here when they are published.',
                      borderColor: Color(0xFF345AE3),
                    ),
                  )
                else
                  ...List<Widget>.generate(controller.propertyItems.length, (
                    index,
                  ) {
                    final item = controller.propertyItems[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PropertyEditorialTile(
                        item: item,
                        borderColor: _propertyTileColor(index),
                        onContact: () => _openPrivateChat(
                          item.userId,
                          'This host chat is not available yet.',
                        ),
                        onOpen: () => _openPropertyDetail(item),
                      ),
                    );
                  }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkStayHero extends StatelessWidget {
  const _WorkStayHero({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.count,
    required this.borderColor,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final int count;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 226,
      child: MetroImageFrame(
        borderColor: borderColor,
        imageUrl: imageUrl,
        onTap: onTap,
        overlayTop: const Color(0x08000000),
        overlayBottom: const Color(0xD2151720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MetroBadge(label: title),
                const Spacer(),
                MetroBadge(
                  label: '$count',
                  backgroundColor: borderColor.withValues(alpha: 0.95),
                  foregroundColor: Colors.white,
                  outlined: false,
                ),
              ],
            ),
            const Spacer(),
            Text(
              context.tr(title),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontSize: 30,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(subtitle),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _WorkStayFilterChipButton(
      label: label,
      selected: selected,
      onTap: onTap,
    );
  }
}

class _JobEditorialTile extends StatelessWidget {
  const _JobEditorialTile({
    required this.item,
    required this.borderColor,
    required this.onContact,
    required this.onOpen,
  });

  final JobListingItem item;
  final Color borderColor;
  final Future<void> Function() onContact;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(kMetroRadius),
      child: MetroInsetPanel(
        borderColor: borderColor,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 154,
              child: MetroImageFrame(
                borderColor: borderColor,
                imageUrl: item.imageUrls.isNotEmpty ? item.imageUrls.first : '',
                padding: const EdgeInsets.all(12),
                overlayTop: const Color(0x06000000),
                overlayBottom: const Color(0x42000000),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MetroBadge(label: _humanize(item.listingMode)),
                    const Spacer(),
                    if (item.salonName.isNotEmpty)
                      MetroBadge(
                        label: item.salonName,
                        backgroundColor: Colors.white.withValues(alpha: 0.88),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(item.title),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: kMetroInk,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(item.description),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: kMetroMuted),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_salary(item).isNotEmpty)
                        MetroBadge(
                          label: _salary(item),
                          backgroundColor: const Color(0xFFFFF2DE),
                        ),
                      if (_location(item.city, item.state).isNotEmpty)
                        MetroBadge(
                          label: _location(item.city, item.state),
                          backgroundColor: const Color(0xFFF0F3FA),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: OutlinedButton(
                            onPressed: onOpen,
                            child: Text(context.tr('View details')),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: FilledButton(
                            onPressed: onContact,
                            style: FilledButton.styleFrom(
                              backgroundColor: borderColor.withValues(
                                alpha: 0.96,
                              ),
                            ),
                            child: Text(
                              context.tr(
                                item.listingMode == 'looking_for_job'
                                    ? 'Message candidate'
                                    : 'Chat recruiter',
                              ),
                            ),
                          ),
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
    );
  }
}

class _PropertyEditorialTile extends StatelessWidget {
  const _PropertyEditorialTile({
    required this.item,
    required this.borderColor,
    required this.onContact,
    required this.onOpen,
  });

  final PropertyListingItem item;
  final Color borderColor;
  final Future<void> Function() onContact;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(kMetroRadius),
      child: MetroInsetPanel(
        borderColor: borderColor,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 154,
              child: MetroImageFrame(
                borderColor: borderColor,
                imageUrl: item.imageUrls.isNotEmpty ? item.imageUrls.first : '',
                padding: const EdgeInsets.all(12),
                overlayTop: const Color(0x06000000),
                overlayBottom: const Color(0x42000000),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MetroBadge(label: _propertyModeLabel(item.listingMode)),
                    const Spacer(),
                    if (item.amenities.isNotEmpty)
                      MetroBadge(
                        label: item.amenities.first,
                        backgroundColor: Colors.white.withValues(alpha: 0.88),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(item.title),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: kMetroInk,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(item.description),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: kMetroMuted),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      MetroBadge(
                        label: _money(item.price, item.currency),
                        backgroundColor: const Color(0xFFFFF2DE),
                      ),
                      if (_location(item.city, item.state).isNotEmpty)
                        MetroBadge(
                          label: _location(item.city, item.state),
                          backgroundColor: const Color(0xFFF0F3FA),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: OutlinedButton(
                            onPressed: onOpen,
                            child: Text(context.tr('View details')),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: FilledButton(
                            onPressed: onContact,
                            style: FilledButton.styleFrom(
                              backgroundColor: borderColor.withValues(
                                alpha: 0.96,
                              ),
                            ),
                            child: Text(
                              context.tr(
                                item.listingMode == 'looking_room'
                                    ? 'Message renter'
                                    : 'Chat host',
                              ),
                            ),
                          ),
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
    );
  }
}

class _WorkStayFilterChipButton extends StatelessWidget {
  const _WorkStayFilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kMetroRadius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? kMetroCoralSoft : kMetroSurface,
          borderRadius: BorderRadius.circular(kMetroRadius),
          border: Border.all(color: selected ? kMetroCoral : kMetroLine),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x10F36C84),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          context.tr(label),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: selected ? kMetroPrimary : kMetroInk,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
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

Color _jobTileColor(int index) {
  const palette = <Color>[
    kMetroGold,
    kMetroSuccess,
    Color(0xFFC18E68),
    kMetroPrimary,
  ];
  return palette[index % palette.length];
}

Color _propertyTileColor(int index) {
  const palette = <Color>[
    kMetroPrimary,
    kMetroSuccess,
    Color(0xFFC18E68),
    kMetroRose,
  ];
  return palette[index % palette.length];
}
