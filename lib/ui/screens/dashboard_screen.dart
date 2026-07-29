import 'package:flutter/material.dart';

import 'create_study_set_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulary Trainer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Context',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'Language Combination',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    DropdownButton<String>(
                      value: 'English → Italian',
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'English → Italian',
                          child: Text('English → Italian'),
                        ),
                      ],
                      onChanged: null,
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Study Set',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    DropdownButton<String>(
                      value: '(No study sets)',
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: '(No study sets)',
                          child: Text('(No study sets)'),
                        ),
                      ],
                      onChanged: null,
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Learning Window',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    const SizedBox(
                      height: 42,
                      child: TextField(
                        enabled: false,
                        decoration: InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          hintText: '50',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Start learning session.
                },
                child: const Text(
                  'Learn',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateStudySetScreen(),
                    ),
                  );
                },
                child: const Text('Manage Study Set'),
              ),
            ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: null,
                child: const Text('Manage Vocabulary'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}