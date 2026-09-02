import 'package:flutter/material.dart';

import '../../domain/language_combination.dart';
import 'compact_dropdown.dart';

class ImportLanguageSelector extends StatelessWidget {
  final List<LanguageCombination> languageCombinations;
  final LanguageCombination? selectedLanguageCombination;
  final ValueChanged<LanguageCombination?> onChanged;

  const ImportLanguageSelector({
    super.key,
    required this.languageCombinations,
    required this.selectedLanguageCombination,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Language Pair',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        CompactDropdown<LanguageCombination>(
          value: selectedLanguageCombination,
          items: languageCombinations.map((languageCombination) {
            return DropdownMenuItem<LanguageCombination>(
              value: languageCombination,
              child: Text(
                '${languageCombination.sourceLanguage} → '
                '${languageCombination.targetLanguage}',
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
