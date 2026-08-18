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

enum WorkStayBoard { jobs, housing }

class WorkStayScreen extends StatefulWidget {
  const WorkStayScreen.jobs({
    this.initialJobMode = 'looking_for_job',
    super.key,
  }) : board = WorkStayBoard.jobs,
       initialPropertyMode = 'rent_out';

  const WorkStayScreen.housing({
    this.initialPropertyMode = 'rent_out',
    super.key,
  }) : board = WorkStayBoard.housing,
       initialJobMode = 'looking_for_job';

  final WorkStayBoard board;
  final String initialJobMode;
  final String initialPropertyMode;

  @override
  State<WorkStayScreen> createState() => _WorkStayScreenState();
}

class _WorkStayScreenState extends State<WorkStayScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _mineOnly = false;
  String? _stateFilter;
  late String _jobMode;
  late String _propertyMode;

  bool get _isJobsBoard => widget.board == WorkStayBoard.jobs;

  String get _pageTitle => _isJobsBoard
      ? _jobModeLabel(_jobMode)
      : _propertyModeLabel(_propertyMode);

  Color get _accentColor => _isJobsBoard
      ? _jobBoardAccent(_jobMode)
      : _propertyBoardAccent(_propertyMode);

  String get _heroSubtitle => _isJobsBoard
      ? (_jobMode == 'hiring'
            ? 'Salon owners are posting open positions here so members can quickly find the right team.'
            : 'Members looking for salon work appear here so owners can discover local talent quickly.')
      : (_propertyMode == 'looking_room'
            ? 'Housing-need posts gather members who are searching for rooms, rentals, or a place to move in.'
            : 'Photo-first rental posts help members browse homes and rooms available right now.');

  String get _sectionTitle => _isJobsBoard
      ? (_jobMode == 'hiring' ? 'Worker search board' : 'Job seeker board')
      : (_propertyMode == 'looking_room'
            ? 'Housing need board'
            : 'Rental board');

  String get _sectionSubtitle => _isJobsBoard
      ? (_jobMode == 'hiring'
            ? 'Open roles are separated into a cleaner list so owners can contact the right people faster.'
            : 'Profiles from people looking for salon work are separated here for faster matching.')
      : (_propertyMode == 'looking_room'
            ? 'Posts from members who need a room or home are grouped here for quicker replies.'
            : 'Available homes and rooms are grouped here so renters can browse quickly.');

  String get _searchHint => _isJobsBoard
      ? (_jobMode == 'hiring'
            ? 'Search worker posts'
            : 'Search job-seeker posts')
      : (_propertyMode == 'looking_room'
            ? 'Search housing needs'
            : 'Search rental homes');

  String get _fabLabel => _isJobsBoard
      ? (_jobMode == 'hiring' ? 'Post Hiring Request' : 'Post Job Search')
      : (_propertyMode == 'looking_room'
            ? 'Post Housing Need'
            : 'Post Rental Home');

  @override
  void initState() {
    super.initState();
    _jobMode = _normalizeJobMode(widget.initialJobMode);
    _propertyMode = _normalizePropertyMode(widget.initialPropertyMode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SocialHubController>().ensureUsStatesLoaded();
      _refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() {
    if (_isJobsBoard) {
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
    final loading = _isJobsBoard
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
        title: Text(context.tr(_pageTitle)),
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
              builder: (_) => _isJobsBoard
                  ? JobFormScreen(initialMode: _jobMode)
                  : PropertyFormScreen(initialMode: _propertyMode),
            ),
          );
          if (created == true && mounted) {
            await _refresh();
          }
        },
        icon: Icon(
          _isJobsBoard ? Icons.work_outline_rounded : Icons.home_work_outlined,
        ),
        label: Text(context.tr(_fabLabel)),
      ),
      body: MetroPageBackground(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 92),
            children: [
              _WorkStayHero(
                title: _pageTitle,
                subtitle: _heroSubtitle,
                imageUrl: _isJobsBoard
                    ? (featuredJob?.imageUrls.isNotEmpty == true
                          ? featuredJob!.imageUrls.first
                          : '')
                    : (featuredProperty?.imageUrls.isNotEmpty == true
                          ? featuredProperty!.imageUrls.first
                          : ''),
                count: _isJobsBoard
                    ? controller.jobItems.length
                    : controller.propertyItems.length,
                borderColor: _accentColor,
                onTap: _isJobsBoard
                    ? (featuredJob == null
                          ? null
                          : () => _openJobDetail(featuredJob))
                    : (featuredProperty == null
                          ? null
                          : () => _openPropertyDetail(featuredProperty)),
              ),
              const SizedBox(height: 16),
              MetroSectionHeader(
                title: _sectionTitle,
                subtitle: _sectionSubtitle,
              ),
              const SizedBox(height: 12),
              MetroInsetPanel(
                borderColor: _accentColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _isJobsBoard
                          ? [
                              _WorkStayFilterChipButton(
                                label: 'Job seekers',
                                selected: _jobMode == 'looking_for_job',
                                onTap: () {
                                  setState(() => _jobMode = 'looking_for_job');
                                  _refresh();
                                },
                              ),
                              _WorkStayFilterChipButton(
                                label: 'Hiring nail staff',
                                selected: _jobMode == 'hiring',
                                onTap: () {
                                  setState(() => _jobMode = 'hiring');
                                  _refresh();
                                },
                              ),
                            ]
                          : [
                              _WorkStayFilterChipButton(
                                label: 'Homes for rent',
                                selected: _propertyMode == 'rent_out',
                                onTap: () {
                                  setState(() => _propertyMode = 'rent_out');
                                  _refresh();
                                },
                              ),
                              _WorkStayFilterChipButton(
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
                      decoration: metroSoftInputDecoration(
                        context,
                        hintText: _searchHint,
                        prefixIcon: const Icon(Icons.search_rounded),
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
              if (_isJobsBoard) ...[
                if (controller.loadingJobs && controller.jobItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (controller.jobItems.isEmpty)
                  SizedBox(
                    height: 210,
                    child: MetroEmptyState(
                      icon: Icons.work_outline_rounded,
                      title: _jobMode == 'hiring'
                          ? 'No worker-search posts yet'
                          : 'No job-seeker posts yet',
                      message: _jobMode == 'hiring'
                          ? 'Salon owners have not posted any worker searches yet.'
                          : 'No members have posted a job search in this area yet.',
                      borderColor: _accentColor,
                    ),
                  )
                else
                  ...List<Widget>.generate(controller.jobItems.length, (index) {
                    final item = controller.jobItems[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _JobEditorialTile(
                        item: item,
                        borderColor: _jobTileColor(index, item.listingMode),
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
                  SizedBox(
                    height: 210,
                    child: MetroEmptyState(
                      icon: Icons.home_work_outlined,
                      title: _propertyMode == 'looking_room'
                          ? 'No housing-need posts yet'
                          : 'No rental-home posts yet',
                      message: _propertyMode == 'looking_room'
                          ? 'No members have posted a housing need in this area yet.'
                          : 'No rental homes have been posted in this area yet.',
                      borderColor: _accentColor,
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
                        borderColor: _propertyTileColor(
                          index,
                          item.listingMode,
                        ),
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
                    MetroBadge(label: _jobModeLabel(item.listingMode)),
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
                          height: 46,
                          child: OutlinedButton(
                            onPressed: onOpen,
                            style: metroSoftOutlinedButtonStyle(context),
                            child: Text(context.tr('View details')),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: FilledButton(
                            onPressed: onContact,
                            style: metroSoftFilledButtonStyle(
                              context,
                              borderColor,
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
                          height: 46,
                          child: OutlinedButton(
                            onPressed: onOpen,
                            style: metroSoftOutlinedButtonStyle(context),
                            child: Text(context.tr('View details')),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: FilledButton(
                            onPressed: onContact,
                            style: metroSoftFilledButtonStyle(
                              context,
                              borderColor,
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

String _normalizeJobMode(String mode) {
  return mode == 'hiring' ? 'hiring' : 'looking_for_job';
}

String _normalizePropertyMode(String mode) {
  return mode == 'looking_room' ? 'looking_room' : 'rent_out';
}

String _jobModeLabel(String mode) {
  switch (mode) {
    case 'hiring':
      return 'Hiring nail staff';
    case 'looking_for_job':
    default:
      return 'Job seekers';
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
      return 'Homes for rent';
  }
}

Color _jobBoardAccent(String mode) {
  return mode == 'hiring' ? kMetroGold : kMetroSuccess;
}

Color _propertyBoardAccent(String mode) {
  return mode == 'looking_room' ? kMetroRose : kMetroPrimary;
}

Color _jobTileColor(int index, String mode) {
  final palette = <Color>[
    _jobBoardAccent(mode),
    mode == 'hiring' ? kMetroSuccess : kMetroGold,
    Color(0xFFC18E68),
    kMetroPrimary,
  ];
  return palette[index % palette.length];
}

Color _propertyTileColor(int index, String mode) {
  final palette = <Color>[
    _propertyBoardAccent(mode),
    mode == 'looking_room' ? kMetroPrimary : kMetroSuccess,
    Color(0xFFC18E68),
    kMetroRose,
  ];
  return palette[index % palette.length];
}
