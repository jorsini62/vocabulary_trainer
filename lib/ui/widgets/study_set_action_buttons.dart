import 'package:flutter/material.dart';

class StudySetActionButtons extends StatelessWidget {
  const StudySetActionButtons({
    super.key,
    required this.onNewStudySet,
    required this.onRenameStudySet,
    required this.onDeleteStudySet,
    this.renameEnabled = true,
    this.deleteEnabled = true,
  });

  final VoidCallback onNewStudySet;
  final VoidCallback onRenameStudySet;
  final VoidCallback onDeleteStudySet;

  final bool renameEnabled;
  final bool deleteEnabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: onNewStudySet,
          child: const Text('New'),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: renameEnabled ? onRenameStudySet : null,
          child: const Text('Rename'),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: deleteEnabled ? onDeleteStudySet : null,
          child: const Text('Delete'),
        ),
      ],
    );
  }
}