import 'package:flutter/material.dart';

import '../core/localization/app_localizer.dart';
import '../models/app_option.dart';

class UsStateDropdownField extends StatelessWidget {
  const UsStateDropdownField({
    required this.states,
    required this.value,
    required this.onChanged,
    this.label = 'State',
    this.required = true,
    this.loading = false,
    this.emptyLabel = 'Select a state',
    super.key,
  });

  final List<AppOption> states;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final bool required;
  final bool loading;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final hasMatch =
        value != null && states.any((state) => state.name == value);

    return DropdownButtonFormField<String?>(
      initialValue: hasMatch ? value : null,
      isExpanded: true,
      menuMaxHeight: 360,
      validator: required
          ? (selected) {
              if (selected == null || selected.trim().isEmpty) {
                return context.tr('Required');
              }
              return null;
            }
          : null,
      decoration: InputDecoration(
        labelText: label,
        helperText: loading && states.isEmpty
            ? context.tr('Loading US states...')
            : null,
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(required ? emptyLabel : context.tr('All states')),
        ),
        ...states.map(
          (state) => DropdownMenuItem<String?>(
            value: state.name,
            child: Text('${state.name} (${state.slug})'),
          ),
        ),
      ],
      onChanged: loading && states.isEmpty ? null : onChanged,
    );
  }
}
