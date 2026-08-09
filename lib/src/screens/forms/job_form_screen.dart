import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/social_hub_controller.dart';
import '../../widgets/us_state_dropdown_field.dart';

class JobFormScreen extends StatefulWidget {
  const JobFormScreen({this.initialMode = 'hiring', super.key});

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
    _salonController.dispose();
    _descriptionController.dispose();
    _requirementsController.dispose();
    _salaryMinController.dispose();
    _salaryMaxController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _imageUrlsController.dispose();
    super.dispose();
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
      imageUrls: _splitInputValues(_imageUrlsController.text),
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SocialHubController>();
    final hiringMode = _selectedMode == 'hiring';
    final pageTitle = hiringMode ? 'Post Job' : 'Post Looking for Job';
    final introText = hiringMode
        ? 'Create a hiring post for nail technicians, salon staff, managers, or part-time team members.'
        : 'Create a profile for professionals looking for work, a new salon, or licensing support.';

    return Scaffold(
      appBar: AppBar(title: Text(pageTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(introText, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'hiring',
                    icon: Icon(Icons.storefront_rounded),
                    label: Text('Hiring nail staff'),
                  ),
                  ButtonSegment<String>(
                    value: 'looking_for_job',
                    icon: Icon(Icons.person_search_rounded),
                    label: Text('Job seekers'),
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
                label: hiringMode ? 'Job Title' : 'Profile Headline',
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _salonController,
                label: hiringMode ? 'Salon Name' : 'Current Salon / Experience',
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _descriptionController,
                label: hiringMode ? 'Job Description' : 'About Me',
                lines: 4,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _requirementsController,
                label: hiringMode ? 'Requirements' : 'Skills / Preferences',
                lines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _salaryMinController,
                      label: 'Salary Min',
                      keyboard: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _salaryMaxController,
                      label: 'Salary Max',
                      keyboard: TextInputType.number,
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
                    controller.submitting
                        ? 'Posting...'
                        : (hiringMode ? 'Publish Job' : 'Publish Profile'),
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
