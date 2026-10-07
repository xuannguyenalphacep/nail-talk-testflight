import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/social_hub_controller.dart';
import '../core/localization/app_localizer.dart';
import '../core/utils/app_date_utils.dart';
import '../models/app_option.dart';
import '../models/clinic_item.dart';
import '../models/service_category.dart';
import '../widgets/metro_ui.dart';
import '../widgets/remote_image.dart';

const Color _clinicTeal = Color(0xFF0F9D96);
const Color _clinicInk = Color(0xFF17395F);
const Color _clinicSoft = Color(0xFFEAF8F7);

class ClinicFinderScreen extends StatefulWidget {
  const ClinicFinderScreen({required this.service, super.key});

  final ServiceCategory service;

  @override
  State<ClinicFinderScreen> createState() => _ClinicFinderScreenState();
}

class _ClinicFinderScreenState extends State<ClinicFinderScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedSpecialty = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SocialHubController>().refreshClinics(
        serviceSlug: widget.service.slug,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() {
    return context.read<SocialHubController>().refreshClinics(
      serviceSlug: widget.service.slug,
      specialty: _selectedSpecialty,
      search: _searchController.text,
    );
  }

  Future<void> _openDetail(ClinicItem clinic) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ClinicDetailScreen(clinic: clinic, service: widget.service),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SocialHubController>();
    final clinics = controller.clinicItems;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MetroPageBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              children: [
                _ClinicHeader(
                  title: widget.service.name,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 18),
                _ClinicHeroBanner(service: widget.service),
                const SizedBox(height: 16),
                _ClinicSearchBar(
                  controller: _searchController,
                  onSubmitted: (_) => _refresh(),
                  onClear: () {
                    _searchController.clear();
                    _refresh();
                  },
                  hintText: _providerSearchHint(widget.service),
                ),
                const SizedBox(height: 14),
                _SpecialtyFilterBar(
                  specialties: controller.clinicSpecialties,
                  selected: _selectedSpecialty,
                  onSelected: (value) {
                    setState(() => _selectedSpecialty = value);
                    _refresh();
                  },
                ),
                if (controller.loadingClinics) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: const LinearProgressIndicator(minHeight: 4),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  _providerListTitle(context, widget.service),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _clinicInk,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                if (clinics.isEmpty && !controller.loadingClinics)
                  _ClinicEmptyState(onRetry: _refresh)
                else
                  ...clinics.map(
                    (clinic) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _ClinicCard(
                        clinic: clinic,
                        onTap: () => _openDetail(clinic),
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

class ClinicDetailScreen extends StatefulWidget {
  const ClinicDetailScreen({
    required this.clinic,
    required this.service,
    super.key,
  });

  final ClinicItem clinic;
  final ServiceCategory service;

  @override
  State<ClinicDetailScreen> createState() => _ClinicDetailScreenState();
}

class _ClinicDetailScreenState extends State<ClinicDetailScreen> {
  late ClinicItem _clinic = widget.clinic;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final clinic = await context
          .read<SocialHubController>()
          .fetchClinicDetail(widget.clinic.id);
      if (mounted) setState(() => _clinic = clinic);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openBooking() {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ClinicBookingScreen(clinic: _clinic, service: widget.service),
      ),
    );
  }

  Future<void> _openUrl(String rawUrl) async {
    final url = Uri.tryParse(rawUrl);
    if (url == null) return;
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
          child: FilledButton.icon(
            style: metroSoftFilledButtonStyle(context, _clinicTeal),
            onPressed: _openBooking,
            icon: const Icon(Icons.event_available_rounded),
            label: Text(context.tr('Request booking')),
          ),
        ),
      ),
      body: MetroPageBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 26),
            children: [
              _ClinicHeader(
                title: widget.service.name,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: 16),
              _ClinicDetailHero(clinic: _clinic, service: widget.service),
              if (_loading) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: const LinearProgressIndicator(minHeight: 4),
                ),
              ],
              const SizedBox(height: 16),
              _InfoPanel(
                title: 'Provider details',
                children: [
                  _InfoRow(
                    icon: Icons.place_rounded,
                    label: _clinic.addressLine.isNotEmpty
                        ? _clinic.addressLine
                        : _clinic.locationLabel,
                  ),
                  if (_clinic.contactPhone.isNotEmpty)
                    _InfoRow(
                      icon: Icons.call_rounded,
                      label: _clinic.contactPhone,
                    ),
                  if (_clinic.contactEmail.isNotEmpty)
                    _InfoRow(
                      icon: Icons.email_rounded,
                      label: _clinic.contactEmail,
                    ),
                ],
              ),
              if (_clinic.description.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                _TextPanel(
                  title: 'About this provider',
                  text: _clinic.description,
                ),
              ],
              if (_clinic.openingHours.isNotEmpty) ...[
                const SizedBox(height: 14),
                _InfoPanel(
                  title: 'Opening hours',
                  children: _clinic.openingHours
                      .map(
                        (item) =>
                            _InfoRow(icon: Icons.schedule_rounded, label: item),
                      )
                      .toList(),
                ),
              ],
              if (_clinic.websiteUrl.isNotEmpty ||
                  _clinic.mapUrl.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (_clinic.mapUrl.isNotEmpty)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: metroSoftOutlinedButtonStyle(context),
                          onPressed: () => _openUrl(_clinic.mapUrl),
                          icon: const Icon(Icons.map_rounded),
                          label: Text(context.tr('Open map')),
                        ),
                      ),
                    if (_clinic.mapUrl.isNotEmpty &&
                        _clinic.websiteUrl.isNotEmpty)
                      const SizedBox(width: 10),
                    if (_clinic.websiteUrl.isNotEmpty)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: metroSoftOutlinedButtonStyle(context),
                          onPressed: () => _openUrl(_clinic.websiteUrl),
                          icon: const Icon(Icons.language_rounded),
                          label: Text(context.tr('Website')),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class ClinicBookingScreen extends StatefulWidget {
  const ClinicBookingScreen({
    required this.clinic,
    required this.service,
    super.key,
  });

  final ClinicItem clinic;
  final ServiceCategory service;

  @override
  State<ClinicBookingScreen> createState() => _ClinicBookingScreenState();
}

class _ClinicBookingScreenState extends State<ClinicBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _preferredTimeController = TextEditingController();
  final _messageController = TextEditingController();

  DateTime? _plannedTravelDate;
  DateTime? _appointmentDate;
  String _specialty = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _preferredTimeController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool appointment}) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: appointment
          ? (_appointmentDate ?? now.add(const Duration(days: 7)))
          : (_plannedTravelDate ?? now.add(const Duration(days: 30))),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (selected == null) return;
    setState(() {
      if (appointment) {
        _appointmentDate = selected;
      } else {
        _plannedTravelDate = selected;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final result = await context
        .read<SocialHubController>()
        .submitClinicBooking(
          clinicId: widget.clinic.id,
          customerName: _nameController.text.trim(),
          customerEmail: _emailController.text.trim(),
          customerPhone: _phoneController.text.trim(),
          currentLocation: _locationController.text.trim(),
          plannedTravelDate: _dateForApi(_plannedTravelDate),
          appointmentDate: _dateForApi(_appointmentDate),
          preferredTime: _preferredTimeController.text.trim(),
          specialty: _specialty,
          message: _messageController.text.trim(),
        );

    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          result.status == 'sent'
              ? context.tr('Your request has been sent to the provider.')
              : context.tr('Your request has been saved for follow-up.'),
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final submitting = context.watch<SocialHubController>().submitting;
    final specialties = widget.clinic.specialtyNames;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MetroPageBackground(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 26),
              children: [
                _ClinicHeader(
                  title: widget.service.name,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 18),
                Text(
                  context.tr('Request booking'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _clinicInk,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _reviewSafeServiceText(context, widget.clinic.name),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: kMetroMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  decoration: metroSoftInputDecoration(
                    context,
                    labelText: 'Full name',
                    hintText: 'Enter your full name',
                    prefixIcon: const Icon(Icons.person_rounded),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? context.tr('Please enter your name.')
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: metroSoftInputDecoration(
                          context,
                          labelText: 'Phone',
                          hintText: 'Phone number',
                          prefixIcon: const Icon(Icons.call_rounded),
                        ),
                        validator: (_) => _contactValidator(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: metroSoftInputDecoration(
                          context,
                          labelText: 'Email',
                          hintText: 'Email address',
                          prefixIcon: const Icon(Icons.email_rounded),
                        ),
                        validator: (_) => _contactValidator(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationController,
                  decoration: metroSoftInputDecoration(
                    context,
                    labelText: 'Current location',
                    hintText: 'Example: California, Tokyo, Osaka',
                    prefixIcon: const Icon(Icons.public_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Vietnam arrival date',
                        value: _plannedTravelDate,
                        onTap: () => _pickDate(appointment: false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateField(
                        label: 'Preferred booking date',
                        value: _appointmentDate,
                        onTap: () => _pickDate(appointment: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (specialties.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _specialty.isEmpty ? null : _specialty,
                    decoration: metroSoftInputDecoration(
                      context,
                      labelText: 'Service / treatment',
                      hintText: 'Choose a service',
                      prefixIcon: const Icon(Icons.spa_rounded),
                    ),
                    items: specialties
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _specialty = value ?? ''),
                  )
                else
                  TextFormField(
                    decoration: metroSoftInputDecoration(
                      context,
                      labelText: 'Service / treatment',
                      hintText: 'What do you need to book?',
                      prefixIcon: const Icon(Icons.spa_rounded),
                    ),
                    onChanged: (value) => _specialty = value.trim(),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _preferredTimeController,
                  decoration: metroSoftInputDecoration(
                    context,
                    labelText: 'Preferred time',
                    hintText: 'Morning, afternoon, or a specific time',
                    prefixIcon: const Icon(Icons.schedule_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageController,
                  minLines: 4,
                  maxLines: 6,
                  decoration: metroSoftInputDecoration(
                    context,
                    labelText: 'Notes for provider',
                    hintText:
                        'Tell the provider which service you want and timing notes',
                    prefixIcon: const Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: metroSoftFilledButtonStyle(context, _clinicTeal),
                  onPressed: submitting ? null : _submit,
                  icon: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    context.tr(
                      submitting
                          ? 'Sending request...'
                          : 'Send booking request',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _contactValidator(BuildContext context) {
    if (_phoneController.text.trim().isEmpty &&
        _emailController.text.trim().isEmpty) {
      return context.tr('Please enter phone or email.');
    }
    return null;
  }
}

class _ClinicHeader extends StatelessWidget {
  const _ClinicHeader({required this.title, required this.onBack});

  final String title;
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
            _reviewSafeServiceText(context, title),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: _clinicInk,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClinicHeroBanner extends StatelessWidget {
  const _ClinicHeroBanner({required this.service});

  final ServiceCategory service;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 188,
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
          service.bannerImageUrl.trim().isEmpty
              ? Image.asset(
                  'assets/branding/vietnam_clinic_banner_bg.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                )
              : RemoteImage(
                  url: service.bannerImageUrl,
                  width: double.infinity,
                  height: 188,
                  errorFallback: Image.asset(
                    'assets/branding/vietnam_clinic_banner_bg.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                  ),
                ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xEE007E83),
                  Color(0x99159BA0),
                  Color(0x00159BA0),
                ],
                stops: [0, 0.56, 1],
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
                _SoftChip(
                  label: service.shortLabel.trim().isEmpty
                      ? _reviewSafeServiceText(context, service.name)
                      : _reviewSafeServiceText(context, service.shortLabel),
                  icon: _serviceIcon(service),
                  color: Colors.white,
                  foreground: _clinicInk,
                ),
                const Spacer(),
                SizedBox(
                  width: 245,
                  child: Text(
                    _reviewSafeServiceText(context, service.displayTitle),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontSize: 24,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  width: 250,
                  child: Text(
                    _reviewSafeServiceText(context, service.displaySummary),
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

class _ClinicSearchBar extends StatelessWidget {
  const _ClinicSearchBar({
    required this.controller,
    required this.onSubmitted,
    required this.onClear,
    required this.hintText,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: metroSoftInputDecoration(
        context,
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: IconButton(
          tooltip: context.tr('Clear'),
          onPressed: onClear,
          icon: const Icon(Icons.close_rounded),
        ),
      ),
    );
  }
}

class _SpecialtyFilterBar extends StatelessWidget {
  const _SpecialtyFilterBar({
    required this.specialties,
    required this.selected,
    required this.onSelected,
  });

  final List<AppOption> specialties;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = [
      AppOption(id: 0, uuid: '', name: context.tr('All'), slug: ''),
      ...specialties,
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final isAll = item.id == 0;
          final value = isAll ? '' : item.name;
          final active = selected == value;
          return ChoiceChip(
            selected: active,
            label: Text(item.name),
            onSelected: (_) => onSelected(value),
            selectedColor: _clinicTeal,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: active ? Colors.white : _clinicInk,
              fontWeight: FontWeight.w800,
            ),
            side: BorderSide(
              color: active ? _clinicTeal : const Color(0xFFE5E8EF),
            ),
          );
        },
      ),
    );
  }
}

class _ClinicCard extends StatelessWidget {
  const _ClinicCard({required this.clinic, required this.onTap});

  final ClinicItem clinic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5EEF0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ClinicThumb(url: clinic.primaryImageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _reviewSafeServiceText(context, clinic.name),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: _clinicInk,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                              ),
                        ),
                      ),
                      if (clinic.isPartner)
                        const Icon(
                          Icons.verified_rounded,
                          color: _clinicTeal,
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _SmallMeta(
                    icon: Icons.place_rounded,
                    label: clinic.locationLabel.isEmpty
                        ? context.tr('Vietnam')
                        : clinic.locationLabel,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _reviewSafeServiceText(context, clinic.summary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: kMetroMuted,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (clinic.specialtyNames.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: clinic.specialtyNames
                          .take(3)
                          .map(
                            (item) => _TinyPill(
                              label: _reviewSafeServiceText(context, item),
                              background: _clinicSoft,
                              foreground: _clinicInk,
                            ),
                          )
                          .toList(),
                    ),
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

class _ClinicDetailHero extends StatelessWidget {
  const _ClinicDetailHero({required this.clinic, required this.service});

  final ClinicItem clinic;
  final ServiceCategory service;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 190,
            width: double.infinity,
            child: clinic.primaryImageUrl.isEmpty
                ? const _ClinicImageFallback()
                : RemoteImage(
                    url: clinic.primaryImageUrl,
                    width: double.infinity,
                    height: 190,
                    errorFallback: const _ClinicImageFallback(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _SoftChip(
                      label: _clinicTypeLabel(context, clinic.clinicType),
                      icon: _serviceIcon(service),
                      color: _clinicSoft,
                      foreground: _clinicInk,
                    ),
                    const Spacer(),
                    if (clinic.isPartner)
                      _SoftChip(
                        label: 'Linked partner',
                        icon: Icons.verified_rounded,
                        color: const Color(0xFFFFF3E1),
                        foreground: const Color(0xFF9C6517),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _reviewSafeServiceText(context, clinic.name),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _clinicInk,
                    fontSize: 25,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _reviewSafeServiceText(context, clinic.summary),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: kMetroMuted,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (clinic.specialtyNames.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: clinic.specialtyNames
                        .map(
                          (item) => _TinyPill(
                            label: _reviewSafeServiceText(context, item),
                            background: _clinicSoft,
                            foreground: _clinicInk,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClinicThumb extends StatelessWidget {
  const _ClinicThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 112,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: url.isEmpty
            ? const _ClinicImageFallback()
            : RemoteImage(
                url: url,
                width: 96,
                height: 112,
                errorFallback: const _ClinicImageFallback(),
              ),
      ),
    );
  }
}

class _ClinicImageFallback extends StatelessWidget {
  const _ClinicImageFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE8FAF8), Color(0xFFFFF3F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.spa_rounded, color: _clinicTeal, size: 32),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(title),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _clinicInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _TextPanel extends StatelessWidget {
  const _TextPanel({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(title),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _clinicInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: kMetroMuted,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelShell extends StatelessWidget {
  const _PanelShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5EEF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _clinicTeal),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _clinicInk,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallMeta extends StatelessWidget {
  const _SmallMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _clinicTeal),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _clinicInk.withValues(alpha: 0.75),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({
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

class _TinyPill extends StatelessWidget {
  const _TinyPill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: InputDecorator(
        decoration: metroSoftInputDecoration(
          context,
          labelText: label,
          hintText: 'Choose date',
          prefixIcon: const Icon(Icons.calendar_month_rounded),
        ),
        child: Text(
          value == null
              ? context.tr('Choose date')
              : AppDateUtils.formatDate(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: value == null ? const Color(0xFF9298AD) : _clinicInk,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ClinicEmptyState extends StatelessWidget {
  const _ClinicEmptyState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      child: Column(
        children: [
          const Icon(Icons.spa_outlined, color: _clinicTeal, size: 42),
          const SizedBox(height: 10),
          Text(
            context.tr('No providers found yet'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _clinicInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr(
              'Linked providers will appear here after admin publishes them.',
            ),
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

String _clinicTypeLabel(BuildContext context, String value) {
  return switch (value) {
    'hospital' => context.tr('Beauty partner'),
    'dental' => context.tr('Beauty partner'),
    'spa' => context.tr('Spa'),
    'beauty' => context.tr('Beauty / Aesthetic'),
    'lab' => context.tr('Beauty partner'),
    _ => context.tr('Service partner'),
  };
}

String _providerSearchHint(ServiceCategory service) {
  return service.slug == 'spa'
      ? 'Search spas, treatments, or cities'
      : 'Search services, partners, or cities';
}

String _providerListTitle(BuildContext context, ServiceCategory service) {
  if (service.slug == 'spa') {
    return context.tr('Linked spas in Vietnam');
  }
  if (service.slug == 'clinic') {
    return context.tr('Linked service partners in Vietnam');
  }
  return context.tr('Linked providers in Vietnam');
}

IconData _serviceIcon(ServiceCategory service) {
  return switch (service.icon.trim().toLowerCase()) {
    'spa' || 'beauty' => Icons.spa_rounded,
    'clinic' || 'hospital' || 'health' => Icons.spa_rounded,
    _ => Icons.room_service_rounded,
  };
}

String _dateForApi(DateTime? date) {
  if (date == null) return '';
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
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
      .replaceAll(RegExp(r'\bmedical\b', caseSensitive: false), 'beauty')
      .replaceAll(
        RegExp(r'phòng khám', caseSensitive: false),
        'đối tác dịch vụ',
      )
      .replaceAll(RegExp(r'bệnh viện', caseSensitive: false), 'đối tác làm đẹp')
      .replaceAll(RegExp(r'y tế', caseSensitive: false), 'dịch vụ làm đẹp')
      .replaceAll(RegExp(r'chuyên khoa', caseSensitive: false), 'dịch vụ')
      .replaceAll(RegExp(r'xét nghiệm', caseSensitive: false), 'dịch vụ')
      .replaceAll(RegExp(r'khám', caseSensitive: false), 'đặt lịch');
}
