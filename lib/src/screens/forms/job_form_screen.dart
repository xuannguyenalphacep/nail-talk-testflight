import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/session_controller.dart';
import '../../controllers/social_hub_controller.dart';
import '../../core/localization/app_localizer.dart';
import '../../widgets/listing_image_picker_field.dart';
import '../../widgets/us_state_dropdown_field.dart';

class JobFormScreen extends StatefulWidget {
  const JobFormScreen({this.initialMode = 'looking_for_job', super.key});

  final String initialMode;

  @override
  State<JobFormScreen> createState() => _JobFormScreenState();
}

class _JobFormScreenState extends State<JobFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _salonController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _requirementsController = TextEditingController();
  final _salaryMinController = TextEditingController();
  final _salaryMaxController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedState;
  late String _selectedMode;
  List<String> _imageUrls = const [];
  bool _uploadingImages = false;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SocialHubController>().ensureUsStatesLoaded();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _salonController.dispose();
    _descriptionController.dispose();
    _requirementsController.dispose();
    _salaryMinController.dispose();
    _salaryMaxController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_uploadingImages) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
      type: FileType.image,
    );
    final files = result?.files ?? const <PlatformFile>[];
    if (files.isEmpty || !mounted) return;

    setState(() => _uploadingImages = true);

    try {
      final session = context.read<SessionController>();
      final nextUrls = List<String>.from(_imageUrls);

      for (final file in files) {
        final uploadedUrl = await session.uploadImage(file);
        nextUrls.add(uploadedUrl);
      }

      if (!mounted) return;
      setState(() => _imageUrls = nextUrls);
    } catch (_) {
      if (!mounted) return;
      final session = context.read<SessionController>();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            session.error ?? context.tr('Could not upload the selected image.'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingImages = false);
      }
    }
  }

  void _removeImageAt(int index) {
    setState(() {
      final next = List<String>.from(_imageUrls);
      next.removeAt(index);
      _imageUrls = next;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = context.read<SocialHubController>();

    await controller.createJobListing(
      title: _titleController.text.trim(),
      salonName: _salonController.text.trim(),
      description: _descriptionController.text.trim(),
      requirements: _requirementsController.text.trim(),
      salaryMin: double.tryParse(_salaryMinController.text.trim()) ?? 0,
      salaryMax: double.tryParse(_salaryMaxController.text.trim()) ?? 0,
      city: _cityController.text.trim(),
      state: _selectedState ?? '',
      contactPhone: _phoneController.text.trim(),
      contactEmail: _emailController.text.trim(),
      mode: _selectedMode,
      imageUrls: _imageUrls,
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SocialHubController>();
    final hiringMode = _selectedMode == 'hiring';
    final pageTitle = hiringMode ? 'Post Hiring Request' : 'Post Job Search';
    final introText = hiringMode
        ? 'Create a hiring post so salon owners can quickly find nail staff, front-desk help, or support workers.'
        : 'Create a job-search profile so salons can discover your skills and contact you faster.';
    final bottomSpacing = MediaQuery.viewPaddingOf(context).bottom + 28;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr(pageTitle))),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomSpacing),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(introText),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment<String>(
                    value: 'hiring',
                    icon: const Icon(Icons.storefront_rounded),
                    label: Text(context.tr('Hiring nail staff')),
                  ),
                  ButtonSegment<String>(
                    value: 'looking_for_job',
                    icon: const Icon(Icons.person_search_rounded),
                    label: Text(context.tr('Job seekers')),
                  ),
                ],
                selected: {_selectedMode},
                onSelectionChanged: (selection) {
                  setState(() => _selectedMode = selection.first);
                },
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _titleController,
                label: context.tr(
                  hiringMode ? 'Job Title' : 'Profile Headline',
                ),
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _salonController,
                label: context.tr(
                  hiringMode ? 'Salon Name' : 'Current Salon / Experience',
                ),
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _descriptionController,
                label: context.tr(hiringMode ? 'Job Description' : 'About Me'),
                lines: 4,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _requirementsController,
                label: context.tr(
                  hiringMode ? 'Requirements' : 'Skills / Preferences',
                ),
                lines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _salaryMinController,
                      label: context.tr('Salary Min'),
                      keyboard: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _salaryMaxController,
                      label: context.tr('Salary Max'),
                      keyboard: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _cityController,
                      label: context.tr('City'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: UsStateDropdownField(
                      states: controller.usStates,
                      value: _selectedState,
                      loading: controller.loadingUsStates,
                      onChanged: (value) =>
                          setState(() => _selectedState = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListingImagePickerField(
                imageUrls: _imageUrls,
                uploading: _uploadingImages,
                label: 'Listing photos',
                helperText:
                    'Add salon or profile photos from your device so people can trust the post faster.',
                onPick: _pickImages,
                onRemoveAt: _removeImageAt,
              ),
              const SizedBox(height: 12),
              _Field(controller: _phoneController, label: context.tr('Phone')),
              const SizedBox(height: 12),
              _Field(controller: _emailController, label: context.tr('Email')),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: controller.submitting || _uploadingImages
                      ? null
                      : _submit,
                  child: Text(
                    _uploadingImages
                        ? context.tr('Uploading images...')
                        : controller.submitting
                        ? context.tr('Posting...')
                        : context.tr(
                            hiringMode
                                ? 'Publish Worker Search'
                                : 'Publish Job Search',
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.lines = 1,
    this.keyboard,
  });

  final TextEditingController controller;
  final String label;
  final int lines;
  final TextInputType? keyboard;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      minLines: lines,
      maxLines: lines,
      validator: (value) =>
          value == null || value.trim().isEmpty ? context.tr('Required') : null,
      decoration: InputDecoration(labelText: label),
    );
  }
}
