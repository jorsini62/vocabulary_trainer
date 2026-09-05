import 'package:flutter/material.dart';

import '../../domain/study_set.dart';

class ImportStudySetSelector extends StatelessWidget {
  final List<StudySet> studySets;
  final StudySet? selectedStudySet;
  final ValueChanged<StudySet?> onChanged;

  const ImportStudySetSelector({
    super.key,
    required this.studySets,
    required this.selectedStudySet,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Study Set',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

        SizedBox(
          width: 360,
          child: DropdownButton<StudySet>(
            value: selectedStudySet,
            isExpanded: true,
            hint: const Text('No Study Set'),
            items: studySets.map((studySet) {
              return DropdownMenuItem<StudySet>(
                value: studySet,
                child: Text(
                  studySet.isDefaultStudySet
                      ? '★ ${studySet.name}'
                      : studySet.name,
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}