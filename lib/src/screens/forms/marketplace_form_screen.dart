import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/session_controller.dart';
import '../../controllers/social_hub_controller.dart';
import '../../core/localization/app_localizer.dart';
import '../../widgets/listing_image_picker_field.dart';
import '../../widgets/us_state_dropdown_field.dart';

class MarketplaceFormScreen extends StatefulWidget {
  const MarketplaceFormScreen({super.key});

  @override
  State<MarketplaceFormScreen> createState() => _MarketplaceFormScreenState();
}

class _MarketplaceFormScreenState extends State<MarketplaceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedState;
  int? _selectedCategoryId;
  List<String> _imageUrls = const [];
  bool _uploadingImages = false;

  @override
  void initState() {
    super.initState();
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

    await controller.createMarketplaceListing(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      price: double.tryParse(_priceController.text.trim()) ?? 0,
      city: _cityController.text.trim(),
      state: _selectedState ?? '',
      contactPhone: _phoneController.text.trim(),
      contactEmail: _emailController.text.trim(),
      categoryId: _selectedCategoryId,
      imageUrls: _imageUrls,
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SocialHubController>();
    final bottomSpacing = MediaQuery.viewPaddingOf(context).bottom + 28;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Create Market Listing'))),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomSpacing),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _Field(controller: _titleController, label: context.tr('Title')),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _selectedCategoryId,
                decoration: InputDecoration(labelText: context.tr('Category')),
                isExpanded: true,
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(context.tr('No category')),
                  ),
                  ...controller.marketplaceCategories.map(
                    (category) => DropdownMenuItem<int?>(
                      value: category.id,
                      child: Text(context.tr(category.name)),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _selectedCategoryId = value);
                },
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _descriptionController,
                label: context.tr('Description'),
                lines: 4,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _priceController,
                label: context.tr('Price (USD)'),
                keyboard: TextInputType.number,
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
                    'Choose clear product photos from your device and the app will upload them automatically.',
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
                        : context.tr('Publish Listing'),
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
