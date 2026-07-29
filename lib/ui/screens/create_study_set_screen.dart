import 'package:flutter/material.dart';

class CreateStudySetScreen extends StatefulWidget {
  const CreateStudySetScreen({super.key});

  @override
  State<CreateStudySetScreen> createState() =>
      _CreateStudySetScreenState();
}

class _CreateStudySetScreenState
    extends State<CreateStudySetScreen> {

  final _sourceLanguageController = TextEditingController();

  final _targetLanguageController = TextEditingController();

  final _studySetNameController = TextEditingController();

  final _learningWindowSizeController =
      TextEditingController(text: '50');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Study Set'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Source Language'),
            TextField(
              controller: _sourceLanguageController,
            ),

            const SizedBox(height: 16),

            const Text('Target Language'),
            TextField(
              controller: _targetLanguageController,
            ),

            const SizedBox(height: 16),

            const Text('Study Set Name'),
            TextField(
              controller: _studySetNameController,
            ),

            const SizedBox(height: 16),

            const Text('Learning Window Size'),
            TextField(
              controller: _learningWindowSizeController,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 16),

            const Text(
              'Suggested Window Size:\n'
              'Standard Learning: 50\n'
              'Intense Learning: 20',
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  print(_sourceLanguageController.text);
                  print(_targetLanguageController.text);
                  print(_studySetNameController.text);
                  print(_learningWindowSizeController.text);

                  Navigator.pop(context);
                },
                child: const Text('Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}