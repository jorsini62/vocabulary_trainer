import 'package:flutter/material.dart';

/// A compact dropdown whose closed control is only as wide as its content.
/// The menu remains readable for longer options without stretching the page.
class CompactDropdown<T> extends StatelessWidget {
  const CompactDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 320),
      child: IntrinsicWidth(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            isExpanded: false,
            isDense: true,
            menuMaxHeight: 360,
          ),
        ),
      ),
    );
  }
}
