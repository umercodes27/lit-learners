import 'package:flutter/material.dart';

/// The plain form controls the admin panel is built from.
///
/// These lived as private classes inside `admin_content_page.dart` until the
/// AI authoring screen needed the same controls to edit a generated draft.
/// They are deliberately unstyled beyond an outline border: the admin panel is
/// a working tool, and its forms should read as forms.
class AdminTextField extends StatelessWidget {
  const AdminTextField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.helperText,
    this.maxLines = 1,
    this.textDirection,
    this.style,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final String? helperText;

  /// Set above 1 for the free-text boxes on the AI request card.
  final int maxLines;

  /// Set for Urdu content so a draft is reviewed laid out the way a child
  /// will actually see it.
  final TextDirection? textDirection;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textDirection: textDirection,
        style: style,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class AdminEnumDropdown<T extends Enum> extends StatelessWidget {
  const AdminEnumDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final item in values)
            DropdownMenuItem(value: item, child: Text(item.name)),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class AdminIntDropdown extends StatelessWidget {
  const AdminIntDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> values;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final item in values)
            DropdownMenuItem(value: item, child: Text(item.toString())),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}
