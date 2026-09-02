import 'package:flutter/material.dart';

import '../../domain/study_set.dart';
import 'compact_dropdown.dart';

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
    // Use the stable StudySet ID as the dropdown value rather than the
    // StudySet object itself. StudySet does not define value equality, so
    // object identity can make Flutter unable to match the selected value
    // to exactly one DropdownMenuItem.
    final byId = <int, StudySet>{};
    for (final studySet in studySets) {
      final id = studySet.id;
      if (id != null) {
        byId[id] = studySet;
      }
    }

    final items = byId.values.map((studySet) {
      return DropdownMenuItem<int>(
        value: studySet.id!,
        child: Text(
          studySet.isDefaultStudySet ? 'Repository' : studySet.name,
        ),
      );
    }).toList();

    final selectedId = selectedStudySet?.id;

    // A selected StudySet can temporarily be absent from the list while the
    // parent reloads it. Passing null avoids Flutter's uniqueness assertion.
    final value = selectedId != null && byId.containsKey(selectedId)
        ? selectedId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Study Set'),
        const SizedBox(height: 4),
        CompactDropdown<int>(
          value: value,
          items: items,
          onChanged: (id) {
            onChanged(id == null ? null : byId[id]);
          },
        ),
      ],
    );
  }
}
