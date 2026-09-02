import 'package:flutter/material.dart';

class StudySetStatistics extends StatelessWidget {
  const StudySetStatistics({
    super.key,
    required this.vocabularyItems,
    required this.activeItems,
    required this.waitingItems,
    required this.deferredItems,
    required this.masteredItems,
  });

  final int? vocabularyItems;
  final int? activeItems;
  final int? waitingItems;
  final int? deferredItems;
  final int? masteredItems;

  Widget _statRow(String label, int? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 210,
            child: Text(label),
          ),
          SizedBox(
            width: 48,
            child: Text(
              value?.toString() ?? '—',
              textAlign: TextAlign.left,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          'Study Set Statistics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        _statRow('Vocabulary Items', vocabularyItems),
        _statRow('Active', activeItems),
        _statRow('Waiting', waitingItems),
        _statRow('Deferred', deferredItems),
        _statRow('Mastered', masteredItems),
      ],
    );
  }
}
