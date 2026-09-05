import 'package:flutter/material.dart';

import '../../domain/study_set.dart';

class StudySetDropdown extends StatelessWidget {
  const StudySetDropdown({
    super.key,
    required this.studySets,
    required this.selectedStudySet,
    required this.onChanged,
  });

  final List<StudySet> studySets;
  final StudySet? selectedStudySet;
  final ValueChanged<StudySet?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Study Set'),
        const SizedBox(height: 4),
        SizedBox(
          width: 280,
          child: DropdownButtonFormField<StudySet>(
            value: selectedStudySet,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            items: studySets.map((studySet) {
              final displayName = studySet.isDefaultStudySet
                  ? '★ ${studySet.name}'
                  : studySet.name;

              return DropdownMenuItem<StudySet>(
                value: studySet,
                child: Text(displayName),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
