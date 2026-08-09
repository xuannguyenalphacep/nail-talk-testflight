import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/social_hub_controller.dart';
import '../../widgets/us_state_dropdown_field.dart';

class PropertyFormScreen extends StatefulWidget {
  const PropertyFormScreen({this.initialMode = 'room_share', super.key});

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
  final _imageUrlsController = TextEditingController();
  String? _selectedState;
  late String _selectedMode;

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
    _imageUrlsController.dispose();
    super.dispose();
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
      imageUrls: _splitInputValues(_imageUrlsController.text),
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SocialHubController>();
    final pageTitle = switch (_selectedMode) {
      'rent_out' => 'Post Rental',
      'looking_room' => 'Post Room Request',
      _ => 'Post Room Share',
    };

    return Scaffold(
      appBar: AppBar(title: Text(pageTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Post a room share, rental home, or housing request anywhere in the United States.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'room_share',
                    icon: Icon(Icons.people_alt_rounded),
                    label: Text('Room share'),
                  ),
                  ButtonSegment<String>(
                    value: 'rent_out',
                    icon: Icon(Icons.house_rounded),
                    label: Text('Homes for rent'),
                  ),
                  ButtonSegment<String>(
                    value: 'looking_room',
                    icon: Icon(Icons.search_rounded),
                    label: Text('Looking for a room'),
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
                label: _selectedMode == 'looking_room'
                    ? 'Need Title'
                    : 'Listing Title',
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _descriptionController,
                label: _selectedMode == 'looking_room'
                    ? 'What you are looking for'
                    : 'Description',
                lines: 4,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _priceController,
                      label: 'Price',
                      keyboard: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _depositController,
                      label: 'Deposit',
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
                    child: _Field(controller: _cityController, label: 'City'),
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
                label: _selectedMode == 'looking_room'
                    ? 'Preferred Area / Address'
                    : 'Address',
                required: _selectedMode != 'looking_room',
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _amenitiesController,
                label: 'Amenities (comma separated)',
                required: false,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _imageUrlsController,
                label: 'Image URLs (comma or new line separated)',
                lines: 3,
                required: false,
              ),
              const SizedBox(height: 12),
              _Field(controller: _phoneController, label: 'Phone'),
              const SizedBox(height: 12),
              _Field(controller: _emailController, label: 'Email'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: controller.submitting ? null : _submit,
                  child: Text(
                    controller.submitting ? 'Posting...' : 'Publish Listing',
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
          ? (value) => value == null || value.trim().isEmpty ? 'Required' : null
          : null,
      decoration: InputDecoration(labelText: label),
    );
  }
}

List<String> _splitInputValues(String raw) {
  return raw
      .split(RegExp(r'[\n,]+'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
}
