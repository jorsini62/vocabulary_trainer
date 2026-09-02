import 'package:flutter/material.dart';

import '../../domain/language_combination.dart';
import '../../domain/study_set.dart';

import '../../repository/sqlite_configuration_repository.dart';
import '../../repository/sqlite_language_combination_repository.dart';
import '../../repository/sqlite_study_set_repository.dart';

import '../widgets/language_pair_dropdown.dart';
import '../widgets/study_set_action_buttons.dart';
import '../widgets/study_set_dropdown.dart';
import '../widgets/study_set_properties.dart';
import '../widgets/study_set_statistics.dart';
import 'transfer_import_center_screen.dart';

class CreateStudySetScreen extends StatefulWidget {
  const CreateStudySetScreen({super.key});

  @override
  State<CreateStudySetScreen> createState() => _CreateStudySetScreenState();
}

class _CreateStudySetScreenState extends State<CreateStudySetScreen> {
  final _studySetNameController = TextEditingController();

  final _standardLearningWindowSizeController = TextEditingController();

  final _intenseLearningWindowSizeController = TextEditingController();

  final _minimumIntervalController = TextEditingController();

  final SQLiteLanguageCombinationRepository _languageCombinationRepository =
      SQLiteLanguageCombinationRepository();

  final SQLiteConfigurationRepository _configurationRepository =
      SQLiteConfigurationRepository();

  final SQLiteStudySetRepository _studySetRepository =
      SQLiteStudySetRepository();

  List<LanguageCombination> _languagePairs = [];

  List<StudySet> _studySets = [];

  LanguageCombination? _selectedLanguagePair;

  StudySet? _selectedStudySet;

  bool _isCreatingNewStudySet = false;

  int? _vocabularyItemsCount;
  int? _activeItemsCount;
  int? _waitingItemsCount;
  int? _deferredItemsCount;
  int? _masteredItemsCount;

  @override
  void initState() {
    super.initState();
    _loadLanguagePairs();
  }

  Future<void> _loadLanguagePairs() async {
    final languagePairs = await _languageCombinationRepository.getAll();

    final configuration = await _configurationRepository.getConfiguration();

    LanguageCombination? selected;

    if (configuration != null) {
      for (final pair in languagePairs) {
        if (pair.id == configuration.currentLanguagePairId) {
          selected = pair;
          break;
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _languagePairs = languagePairs;
      _selectedLanguagePair = selected;
    });

    await _loadStudySets();
  }

  Future<void> _loadStudySets() async {
    if (_selectedLanguagePair == null) {
      if (!mounted) return;

      setState(() {
        _studySets = [];
        _selectedStudySet = null;
        _vocabularyItemsCount = null;
        _activeItemsCount = null;
        _waitingItemsCount = null;
        _deferredItemsCount = null;
        _masteredItemsCount = null;
      });

      return;
    }

    final studySets = await _studySetRepository
        .getStudySetsByLanguageCombinationId(_selectedLanguagePair!.id!);

    if (!mounted) return;

    setState(() {
      _studySets = studySets;

      _selectedStudySet = studySets.isEmpty ? null : studySets.first;

      _isCreatingNewStudySet = false;
    });

    _populateControllers();
    await _loadStudySetStatistics();
  }

  Future<void> _loadStudySetStatistics() async {
    final studySet = _selectedStudySet;

    if (studySet?.id == null) {
      if (!mounted) return;

      setState(() {
        _vocabularyItemsCount = null;
        _activeItemsCount = null;
        _waitingItemsCount = null;
        _deferredItemsCount = null;
        _masteredItemsCount = null;
      });
      return;
    }

    final statistics = await _studySetRepository.getStudySetStatistics(
      studySet!.id!,
    );

    if (!mounted) return;

    setState(() {
      _vocabularyItemsCount = statistics['vocabularyItems'];
      _activeItemsCount = statistics['activeItems'];
      _waitingItemsCount = statistics['waitingItems'];
      _deferredItemsCount = statistics['deferredItems'];
      _masteredItemsCount = statistics['masteredItems'];
    });
  }

  void _populateControllers() {
    final studySet = _selectedStudySet;

    if (studySet == null) {
      _studySetNameController.clear();
      _standardLearningWindowSizeController.clear();
      _intenseLearningWindowSizeController.clear();
      _minimumIntervalController.clear();
      return;
    }

    _studySetNameController.text = studySet.name;

    _standardLearningWindowSizeController.text = studySet
        .standardLearningWindowSize
        .toString();

    _intenseLearningWindowSizeController.text = studySet
        .intenseLearningWindowSize
        .toString();

    _minimumIntervalController.text = studySet.minimumInterval.toString();
  }

  @override
  void dispose() {
    _studySetNameController.dispose();
    _standardLearningWindowSizeController.dispose();
    _intenseLearningWindowSizeController.dispose();
    _minimumIntervalController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Study Sets')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LanguagePairDropdown(
                languagePairs: _languagePairs,
                selectedLanguagePair: _selectedLanguagePair,
                onChanged: (value) async {
                  setState(() {
                    _selectedLanguagePair = value;
                  });

                  await _loadStudySets();
                },
              ),

              const SizedBox(height: 24),

              StudySetDropdown(
                studySets: _studySets,
                selectedStudySet: _selectedStudySet,
                onChanged: (value) async {
                  if (value == null) return;

                  setState(() {
                    _selectedStudySet = value;
                    _isCreatingNewStudySet = false;
                  });

                  _populateControllers();
                  await _loadStudySetStatistics();
                },
              ),

              const SizedBox(height: 24),

              StudySetActionButtons(
                onNewStudySet: _newStudySet,

                onRenameStudySet: _renameStudySet,

                onDeleteStudySet: _deleteStudySet,

                renameEnabled: _selectedStudySet != null,
                deleteEnabled:
                    _selectedStudySet != null &&
                    !_selectedStudySet!.isDefaultStudySet,
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: 180,
                child: OutlinedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TransferImportCenterScreen(),
                      ),
                    );
                    if (mounted) {
                      await _loadStudySets();
                      await _loadStudySetStatistics();
                    }
                  },
                  child: const Text('Transfer & Import'),
                ),
              ),

              const SizedBox(height: 24),

              StudySetProperties(
                standardLearningWindowSizeController:
                    _standardLearningWindowSizeController,
                intenseLearningWindowSizeController:
                    _intenseLearningWindowSizeController,
                minimumIntervalController: _minimumIntervalController,
                showSuggestedValues: _isCreatingNewStudySet,
              ),

              const SizedBox(height: 24),

              StudySetStatistics(
                vocabularyItems: _vocabularyItemsCount,
                activeItems: _activeItemsCount,
                waitingItems: _waitingItemsCount,
                deferredItems: _deferredItemsCount,
                masteredItems: _masteredItemsCount,
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveStudySet,
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _renameStudySet() async {
    if (_selectedStudySet == null) return;

    final controller = TextEditingController(text: _selectedStudySet!.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Study Set'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'New Name'),
            onSubmitted: (value) {
              Navigator.pop(context, value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    if (newName == null) return;

    if (newName.isEmpty) return;

    if (newName == _selectedStudySet!.name) return;

    final updatedStudySet = StudySet(
      id: _selectedStudySet!.id,
      languageCombinationId: _selectedStudySet!.languageCombinationId,
      name: newName,
      standardLearningWindowSize: _selectedStudySet!.standardLearningWindowSize,
      intenseLearningWindowSize: _selectedStudySet!.intenseLearningWindowSize,
      minimumInterval: _selectedStudySet!.minimumInterval,
      isDefaultStudySet: _selectedStudySet!.isDefaultStudySet,
    );

    await _studySetRepository.updateStudySet(updatedStudySet);

    await _loadStudySets();

    if (!mounted) return;

    setState(() {
      _selectedStudySet = _studySets.firstWhere(
        (studySet) => studySet.id == updatedStudySet.id,
      );
    });

    _populateControllers();
    await _loadStudySetStatistics();
  }

  Future<void> _newStudySet() async {
    if (_selectedLanguagePair == null) return;

    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Study Set'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Study Set Name'),
            onSubmitted: (value) {
              Navigator.pop(context, value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (name == null) return;

    if (name.isEmpty) return;

    final newStudySet = StudySet(
      languageCombinationId: _selectedLanguagePair!.id!,
      name: name,
      standardLearningWindowSize: 50,
      intenseLearningWindowSize: 20,
      minimumInterval: 5,
      isDefaultStudySet: false,
    );

    final newId = await _studySetRepository.insertStudySet(newStudySet);

    await _loadStudySets();

    if (!mounted) return;

    setState(() {
      _selectedStudySet = _studySets.firstWhere(
        (studySet) => studySet.id == newId,
      );
    });

    _populateControllers();
    await _loadStudySetStatistics();
  }

  Future<void> _deleteStudySet() async {
    if (_selectedStudySet == null) return;

    if (_selectedStudySet!.isDefaultStudySet) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Study Set'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Delete this Study Set?'),
              const SizedBox(height: 12),
              Text(
                _selectedStudySet!.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('The vocabulary items will not be deleted.'),
              const SizedBox(height: 8),
              const Text('This action cannot be undone.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _studySetRepository.deleteStudySet(_selectedStudySet!.id!);

    await _loadStudySets();

    if (!mounted) return;

    setState(() {
      _selectedStudySet = _studySets.isEmpty ? null : _studySets.first;
    });

    _populateControllers();
    await _loadStudySetStatistics();
  }

  Future<void> _saveStudySet() async {
    if (_selectedStudySet == null) {
      return;
    }

    final updatedStudySet = StudySet(
      id: _selectedStudySet!.id,
      languageCombinationId: _selectedStudySet!.languageCombinationId,
      name: _studySetNameController.text.trim(),
      standardLearningWindowSize:
          int.tryParse(_standardLearningWindowSizeController.text) ??
          _selectedStudySet!.standardLearningWindowSize,
      intenseLearningWindowSize:
          int.tryParse(_intenseLearningWindowSizeController.text) ??
          _selectedStudySet!.intenseLearningWindowSize,
      minimumInterval:
          int.tryParse(_minimumIntervalController.text) ??
          _selectedStudySet!.minimumInterval,
      isDefaultStudySet: _selectedStudySet!.isDefaultStudySet,
    );

    await _studySetRepository.updateStudySet(updatedStudySet);

    await _loadStudySets();

    if (!mounted) return;

    setState(() {
      _selectedStudySet = _studySets.firstWhere(
        (studySet) => studySet.id == updatedStudySet.id,
      );
    });

    _populateControllers();
    await _loadStudySetStatistics();
  }
}
