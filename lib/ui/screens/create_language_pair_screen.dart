import 'package:flutter/material.dart';

import '../../domain/configuration.dart';
import '../../domain/language_combination.dart';
import '../../domain/study_set.dart';
import '../../repository/sqlite_configuration_repository.dart';
import '../../repository/sqlite_language_combination_repository.dart';
import '../../repository/sqlite_study_set_repository.dart';
import '../../repository/sqlite_vocabulary_repository.dart';
import '../widgets/app_message_dialog.dart';

class CreateLanguagePairScreen extends StatefulWidget {
  const CreateLanguagePairScreen({super.key});

  @override
  State<CreateLanguagePairScreen> createState() =>
      _CreateLanguagePairScreenState();
}

class _CreateLanguagePairScreenState extends State<CreateLanguagePairScreen> {
  final TextEditingController _sourceLanguageController =
      TextEditingController();
  final TextEditingController _targetLanguageController =
      TextEditingController();
  final FocusNode _sourceLanguageFocusNode = FocusNode();

  final SQLiteLanguageCombinationRepository _languageCombinationRepository =
      SQLiteLanguageCombinationRepository();
  final SQLiteStudySetRepository _studySetRepository =
      SQLiteStudySetRepository();
  final SQLiteVocabularyRepository _vocabularyRepository =
      SQLiteVocabularyRepository();
  final SQLiteConfigurationRepository _configurationRepository =
      SQLiteConfigurationRepository();

  List<LanguageCombination> _languageCombinations = [];
  LanguageCombination? _selectedLanguageCombination;

  bool _working = false;

  @override
  void initState() {
    super.initState();
    _loadLanguageCombinations();
  }

  @override
  void dispose() {
    _sourceLanguageController.dispose();
    _targetLanguageController.dispose();
    _sourceLanguageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadLanguageCombinations({int? preferredId}) async {
    final combinations = (await _languageCombinationRepository.getAll())
        .where((pair) =>
            pair.sourceLanguage.trim().isNotEmpty &&
            pair.targetLanguage.trim().isNotEmpty)
        .toList();
    if (!mounted) return;

    final selectedId = preferredId ?? _selectedLanguageCombination?.id;
    final selected = selectedId == null
        ? null
        : combinations.cast<LanguageCombination?>().firstWhere(
            (pair) => pair?.id == selectedId,
            orElse: () => null,
          );

    setState(() {
      _languageCombinations = combinations;
      _selectedLanguageCombination = selected;
    });
  }

  Future<void> _showMessage(String title, String message) async {
    if (!mounted) return;
    await AppMessageDialog.show(
      context,
      title: title,
      message: message,
    );
  }

  Future<void> _createLanguagePair() async {
    final source = _sourceLanguageController.text.trim();
    final target = _targetLanguageController.text.trim();

    if (source.isEmpty || target.isEmpty) {
      await _showMessage(
        'Incomplete Language Pair',
        'Please enter both a source language and a target language.',
      );
      return;
    }

    final existing = await _languageCombinationRepository.getAll();
    final duplicate = existing.any(
      (pair) =>
          pair.sourceLanguage.trim().toLowerCase() == source.toLowerCase() &&
          pair.targetLanguage.trim().toLowerCase() == target.toLowerCase(),
    );

    if (duplicate) {
      await _showMessage(
        'Language Pair Already Exists',
        'The Language Pair “$source → $target” already exists.',
      );
      return;
    }

    setState(() {
      _working = true;
    });

    try {
      final id = await _languageCombinationRepository.insert(
        LanguageCombination(
          sourceLanguage: source,
          targetLanguage: target,
        ),
      );

      final repositoryId = await _studySetRepository.insertStudySet(
        StudySet(
          languageCombinationId: id,
          name: 'Repository',
          standardLearningWindowSize: 50,
          intenseLearningWindowSize: 20,
          minimumInterval: 5,
          isDefaultStudySet: true,
        ),
      );

      await _configurationRepository.saveConfiguration(
        Configuration(
          id: 1,
          currentLanguagePairId: id,
          currentStudySetId: repositoryId,
        ),
      );

      await _loadLanguageCombinations(preferredId: id);
      _sourceLanguageController.clear();
      _targetLanguageController.clear();
      FocusScope.of(context).requestFocus(_sourceLanguageFocusNode);
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _deleteLanguagePair() async {
    final pair = _selectedLanguageCombination;
    if (pair == null || pair.id == null) return;

    final studySets = await _studySetRepository
        .getStudySetsByLanguageCombinationId(pair.id!);
    final vocabulary = await _vocabularyRepository
        .getVocabularyItemsByLanguageCombinationId(pair.id!);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Language Pair'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${pair.sourceLanguage} → ${pair.targetLanguage}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Text('This will permanently delete:'),
              const SizedBox(height: 6),
              Text('• ${studySets.length} Study Set(s)'),
              Text('• ${vocabulary.length} Vocabulary Item(s)'),
              const SizedBox(height: 10),
              const Text(
                'All learning history and Study Set memberships for these '
                'Vocabulary Items will also be deleted.',
              ),
              const SizedBox(height: 10),
              const Text('This action cannot be undone.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete Language Pair'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _working = true;
    });

    try {
      final configuration = await _configurationRepository.getConfiguration();
      final deletingCurrent =
          configuration?.currentLanguagePairId == pair.id;

      if (deletingCurrent) {
        await _configurationRepository.saveConfiguration(
          Configuration(
            id: configuration!.id,
            currentLanguagePairId: null,
            currentStudySetId: null,
          ),
        );
      }

      await _languageCombinationRepository.delete(pair.id!);

      await _loadLanguageCombinations();

      if (!mounted) return;
      setState(() {
        _selectedLanguageCombination = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Language Pair')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Language Pair',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 320,
              child: TextField(
                controller: _sourceLanguageController,
                focusNode: _sourceLanguageFocusNode,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Source Language',
                ),
                onSubmitted: (_) {
                  FocusScope.of(context).nextFocus();
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 320,
              child: TextField(
                controller: _targetLanguageController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Target Language',
                ),
                onSubmitted: (_) => _createLanguagePair(),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: 210,
              child: ElevatedButton(
                onPressed: _working ? null : _createLanguagePair,
                child: const Text('Create Language Pair'),
              ),
            ),
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 18),
            const Text(
              'Existing Language Pair',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 320,
              child: DropdownButton<LanguageCombination>(
                value: _selectedLanguageCombination,
                isExpanded: true,
                hint: const Text('No Language Pair selected'),
                items: _languageCombinations.map((pair) {
                  return DropdownMenuItem<LanguageCombination>(
                    value: pair,
                    child: Text(
                      '${pair.sourceLanguage} → ${pair.targetLanguage}',
                    ),
                  );
                }).toList(),
                onChanged: _working
                    ? null
                    : (value) {
                        setState(() {
                          _selectedLanguageCombination = value;
                        });
                      },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 210,
              child: OutlinedButton(
                onPressed: _working || _selectedLanguageCombination == null
                    ? null
                    : _deleteLanguagePair,
                child: const Text('Delete Language Pair'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
