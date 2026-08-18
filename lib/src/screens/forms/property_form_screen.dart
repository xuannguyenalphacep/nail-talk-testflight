import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/session_controller.dart';
import '../../controllers/social_hub_controller.dart';
import '../../core/localization/app_localizer.dart';
import '../../widgets/listing_image_picker_field.dart';
import '../../widgets/us_state_dropdown_field.dart';

class PropertyFormScreen extends StatefulWidget {
  const PropertyFormScreen({this.initialMode = 'rent_out', super.key});

  final String initialMode;

  @override
  State<PropertyFormScreen> createState() => _PropertyFormScreenState();
}

class _PropertyFormScreenState extends State<PropertyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _depositController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _amenitiesController = TextEditingController();
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
    _descriptionController.dispose();
    _priceController.dispose();
    _depositController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _amenitiesController.dispose();
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
    final amenities = _amenitiesController.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    await controller.createPropertyListing(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      price: double.tryParse(_priceController.text.trim()) ?? 0,
      depositAmount: double.tryParse(_depositController.text.trim()) ?? 0,
      city: _cityController.text.trim(),
      state: _selectedState ?? '',
      addressLine: _addressController.text.trim(),
      contactPhone: _phoneController.text.trim(),
      contactEmail: _emailController.text.trim(),
      amenities: amenities,
      mode: _selectedMode,
      imageUrls: _imageUrls,
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SocialHubController>();
    final pageTitle = switch (_selectedMode) {
      'looking_room' => 'Post Housing Need',
      _ => 'Post Rental Home',
    };
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
                context.tr(
                  'Post a rental home or housing request anywhere in the United States.',
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment<String>(
                    value: 'rent_out',
                    icon: const Icon(Icons.house_rounded),
                    label: Text(context.tr('Homes for rent')),
                  ),
                  ButtonSegment<String>(
                    value: 'looking_room',
                    icon: const Icon(Icons.search_rounded),
                    label: Text(context.tr('Looking for a room')),
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
                  _selectedMode == 'looking_room'
                      ? 'Need Title'
                      : 'Listing Title',
                ),
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _descriptionController,
                label: context.tr(
                  _selectedMode == 'looking_room'
                      ? 'What you are looking for'
                      : 'Description',
                ),
                lines: 4,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _priceController,
                      label: context.tr('Price'),
                      keyboard: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _depositController,
                      label: context.tr('Deposit'),
                      keyboard: TextInputType.number,
                      required: false,
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
              _Field(
                controller: _addressController,
                label: context.tr(
                  _selectedMode == 'looking_room'
                      ? 'Preferred Area / Address'
                      : 'Address',
                ),
                required: _selectedMode != 'looking_room',
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _amenitiesController,
                label: context.tr('Amenities (comma separated)'),
                required: false,
              ),
              const SizedBox(height: 12),
              ListingImagePickerField(
                imageUrls: _imageUrls,
                uploading: _uploadingImages,
                label: 'Listing photos',
                helperText:
                    'Upload room or home photos from your device so renters can review the space quickly.',
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
                            _selectedMode == 'looking_room'
                                ? 'Publish Housing Need'
                                : 'Publish Rental Home',
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
    this.required = true,
  });

  final TextEditingController controller;
  final String label;
  final int lines;
  final TextInputType? keyboard;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      minLines: lines,
      maxLines: lines,
      validator: required
          ? (value) => value == null || value.trim().isEmpty
                ? context.tr('Required')
                : null
          : null,
      decoration: InputDecoration(labelText: label),
    );
  }
}
