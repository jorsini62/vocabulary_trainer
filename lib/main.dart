import 'package:flutter/material.dart';
import 'ui/screens/dashboard_screen.dart';

void main() {
  runApp(const VocabularyTrainerApp());
}

class VocabularyTrainerApp extends StatelessWidget {
  const VocabularyTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vocabulary Trainer',
      home: const DashboardScreen(),
    );
  }
}
