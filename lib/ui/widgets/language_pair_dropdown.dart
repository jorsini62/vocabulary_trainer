import 'package:flutter/material.dart';

import '../../domain/language_combination.dart';
import 'compact_dropdown.dart';

class LanguagePairDropdown extends StatelessWidget {
  const LanguagePairDropdown({
    super.key,
    required this.languagePairs,
    required this.selectedLanguagePair,
    required this.onChanged,
  });

  final List<LanguageCombination> languagePairs;
  final LanguageCombination? selectedLanguagePair;
  final ValueChanged<LanguageCombination?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Language Pair'),
        const SizedBox(height: 4),
        CompactDropdown<LanguageCombination>(
          value: selectedLanguagePair,
          items: languagePairs.map((pair) {
            return DropdownMenuItem<LanguageCombination>(
              value: pair,
              child: Text(
                '${pair.sourceLanguage} → ${pair.targetLanguage}',
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
