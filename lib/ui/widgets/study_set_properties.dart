import 'package:flutter/material.dart';

class StudySetProperties extends StatelessWidget {
  const StudySetProperties({
    super.key,
    required this.standardLearningWindowSizeController,
    required this.intenseLearningWindowSizeController,
    required this.minimumIntervalController,
    this.showSuggestedValues = false,
  });

  final TextEditingController standardLearningWindowSizeController;
  final TextEditingController intenseLearningWindowSizeController;
  final TextEditingController minimumIntervalController;

  final bool showSuggestedValues;

  Widget _numberRow({
    required String label,
    required TextEditingController controller,
    required String suggestedValue,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 300,
            child: Text(label),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.only(bottom: 2),
              ),
            ),
          ),
          if (showSuggestedValues) ...[
            const SizedBox(width: 12),
            Text(
              'Suggested: $suggestedValue',
              style: const TextStyle(fontSize: 12),
            ),
          ],
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
          'Study Set Properties',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _numberRow(
          label: 'Standard Learning Window',
          controller: standardLearningWindowSizeController,
          suggestedValue: '50',
        ),
        _numberRow(
          label: 'Intense Learning Window',
          controller: intenseLearningWindowSizeController,
          suggestedValue: '20',
        ),
        _numberRow(
          label: 'Minimum Interval',
          controller: minimumIntervalController,
          suggestedValue: '5',
        ),
      ],
    );
  }
}
