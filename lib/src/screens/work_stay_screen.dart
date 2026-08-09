import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/chat_controller.dart';
import '../controllers/social_hub_controller.dart';
import '../models/job_listing_item.dart';
import '../models/property_listing_item.dart';
import '../widgets/remote_image.dart';
import '../widgets/us_state_dropdown_field.dart';
import 'chat_home_screen.dart';
import 'forms/job_form_screen.dart';
import 'forms/property_form_screen.dart';

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
          content: Text(unavailableMessage),
        ),
      );
      return;
    }

    final chat = context.read<ChatController>();
    await chat.connectIfNeeded();
    await chat.openPrivateChatByUserId(userId);
    if (!mounted || chat.activeRoom == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SocialHubController>();
    final loading = _segment == 0
        ? controller.loadingJobs
        : controller.loadingProperties;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Work & Stay'),
        actions: [
          IconButton(
            onPressed: loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
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
        label: Text(_segment == 0 ? 'Post Job' : 'Post Housing'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.content_cut_rounded),
                  label: Text('Nail Jobs'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.home_work_rounded),
                  label: Text('Room Share'),
                ),
              ],
              selected: {_segment},
              onSelectionChanged: (selection) {
                setState(() => _segment = selection.first);
                _refresh();
              },
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
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
                            setState(() => _propertyMode = 'looking_room');
                            _refresh();
                          },
                        ),
                      ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: _segment == 0 ? 'Search jobs' : 'Search rooms',
                      suffixIcon: IconButton(
                        onPressed: _refresh,
                        icon: const Icon(Icons.search_rounded),
                      ),
                    ),
                    onSubmitted: (_) => _refresh(),
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: const Text('My posts'),
                  selected: _mineOnly,
                  onSelected: (value) {
                    setState(() => _mineOnly = value);
                    _refresh();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            UsStateDropdownField(
              states: controller.usStates,
              value: _stateFilter,
              required: false,
              loading: controller.loadingUsStates,
              onChanged: (value) {
                setState(() => _stateFilter = value);
                _refresh();
              },
            ),
            const SizedBox(height: 14),
            if (_segment == 0) ...[
              if (controller.loadingJobs && controller.jobItems.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                ...controller.jobItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _JobCard(
                      item: item,
                      onSave: () => controller.toggleBookmark(
                        type: 'job_listing',
                        id: item.id,
                      ),
                      onContact: () => _openPrivateChat(
                        item.userId,
                        'This recruiter chat is not available yet.',
                      ),
                    ),
                  ),
                ),
            ] else ...[
              if (controller.loadingProperties &&
                  controller.propertyItems.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                ...controller.propertyItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _PropertyCard(
                      item: item,
                      onSave: () => controller.toggleBookmark(
                        type: 'property_listing',
                        id: item.id,
                      ),
                      onContact: () => _openPrivateChat(
                        item.userId,
                        'This host chat is not available yet.',
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.item,
    required this.onSave,
    required this.onContact,
  });

  final JobListingItem item;
  final Future<void> Function() onSave;
  final Future<void> Function() onContact;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ListingImageHeader(
            imageUrl: item.imageUrls.isEmpty ? '' : item.imageUrls.first,
            saved: item.saved,
            fallbackIcon: Icons.content_cut_rounded,
            badgeLabel: _jobModeLabel(item.listingMode),
            onSave: onSave,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${item.salonName} • ${item.city}, ${item.state}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF52627A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ListingBadge(
                      label:
                          '${item.salaryCurrency} ${item.salaryMin?.toStringAsFixed(0) ?? '-'} - ${item.salaryMax?.toStringAsFixed(0) ?? '-'}',
                    ),
                    if (item.contactPhone.isNotEmpty)
                      _ListingBadge(label: item.contactPhone),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onContact,
                    icon: const Icon(Icons.chat_rounded),
                    label: Text(
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
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({
    required this.item,
    required this.onSave,
    required this.onContact,
  });

  final PropertyListingItem item;
  final Future<void> Function() onSave;
  final Future<void> Function() onContact;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ListingImageHeader(
            imageUrl: item.imageUrls.isEmpty ? '' : item.imageUrls.first,
            saved: item.saved,
            fallbackIcon: Icons.home_work_rounded,
            badgeLabel: _propertyModeLabel(item.listingMode),
            onSave: onSave,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${item.currency} ${item.price.toStringAsFixed(0)} • ${item.city}, ${item.state}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF52627A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (item.addressLine.isNotEmpty)
                      _ListingBadge(label: item.addressLine),
                    ...item.amenities.take(2).map(_buildAmenityBadge),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onContact,
                    icon: const Icon(Icons.forum_rounded),
                    label: Text(
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
    );
  }
}

Widget _buildAmenityBadge(String amenity) {
  return _ListingBadge(label: amenity);
}

class _ListingImageHeader extends StatelessWidget {
  const _ListingImageHeader({
    required this.imageUrl,
    required this.saved,
    required this.fallbackIcon,
    required this.badgeLabel,
    required this.onSave,
  });

  final String imageUrl;
  final bool saved;
  final IconData fallbackIcon;
  final String badgeLabel;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: imageUrl.isEmpty
              ? _ListingImagePlaceholder(icon: fallbackIcon)
              : RemoteImage(
                  url: imageUrl,
                  fit: BoxFit.cover,
                  errorFallback: _ListingImagePlaceholder(icon: fallbackIcon),
                ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.04),
                  Colors.black.withValues(alpha: 0.34),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        Positioned(
          left: 14,
          bottom: 14,
          child: _ListingBadge(label: badgeLabel, light: true),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Material(
            color: Colors.white.withValues(alpha: 0.92),
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: onSave,
              icon: Icon(
                saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ListingImagePlaceholder extends StatelessWidget {
  const _ListingImagePlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE7EEF9), Color(0xFFD7E9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(icon, size: 34, color: const Color(0xFF4A6FA5)),
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
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _ListingBadge extends StatelessWidget {
  const _ListingBadge({required this.label, this.light = false});

  final String label;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: light
            ? Colors.white.withValues(alpha: 0.88)
            : const Color(0xFFF0F6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: light ? const Color(0xFF26415F) : const Color(0xFF2A5CAA),
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
