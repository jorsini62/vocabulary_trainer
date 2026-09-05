import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../domain/configuration.dart';
import '../../domain/language_combination.dart';
import '../../domain/study_set.dart';
import '../../repository/sqlite_configuration_repository.dart';
import '../../repository/sqlite_language_combination_repository.dart';
import '../../repository/sqlite_study_set_repository.dart';
import '../../transfer/transfer_json_codec.dart';
import '../../transfer/transfer_models.dart';
import '../../transfer/transfer_service.dart';

enum TransferScreenMode {
  all,
  databaseExport,
  databaseImport,
  studySetExport,
  studySetImport,
}

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key, this.mode = TransferScreenMode.all});

  final TransferScreenMode mode;

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _languageRepository = SQLiteLanguageCombinationRepository();
  final _studySetRepository = SQLiteStudySetRepository();
  final _configurationRepository = SQLiteConfigurationRepository();
  final _transferService = TransferService();
  final _transferCodec = TransferJsonCodec();

  List<LanguageCombination> _languagePairs = [];
  List<StudySet> _studySets = [];
  LanguageCombination? _selectedLanguagePair;
  StudySet? _selectedStudySet;

  LanguageCombination? _importLanguagePair;
  List<StudySet> _importTargetStudySets = [];
  StudySet? _importTargetStudySet;
  String? _selectedImportFileName;
  String? _selectedImportFilePath;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    final languagePairs = await _languageRepository.getAll();
    final allStudySets = await _studySetRepository.getAllStudySets();
    final configuration = await _configurationRepository.getConfiguration();

    LanguageCombination? selectedLanguagePair;
    StudySet? selectedStudySet;

    if (configuration?.currentLanguagePairId != null) {
      for (final pair in languagePairs) {
        if (pair.id == configuration!.currentLanguagePairId) {
          selectedLanguagePair = pair;
          break;
        }
      }
    }

    selectedLanguagePair ??=
        languagePairs.isNotEmpty ? languagePairs.first : null;

    final filteredStudySets = selectedLanguagePair == null
        ? <StudySet>[]
        : allStudySets
            .where(
              (studySet) =>
                  studySet.languageCombinationId == selectedLanguagePair!.id,
            )
            .toList();

    if (configuration?.currentStudySetId != null) {
      for (final studySet in filteredStudySets) {
        if (studySet.id == configuration!.currentStudySetId) {
          selectedStudySet = studySet;
          break;
        }
      }
    }

    selectedStudySet ??=
        filteredStudySets.isNotEmpty ? filteredStudySets.first : null;

    if (!mounted) return;
    setState(() {
      _languagePairs = languagePairs;
      _selectedLanguagePair = selectedLanguagePair;
      _studySets = filteredStudySets;
      _selectedStudySet = selectedStudySet;
    });
  }

  Future<void> _selectLanguagePair(LanguageCombination? value) async {
    if (value == null) return;

    final allStudySets = await _studySetRepository.getAllStudySets();
    final studySets = allStudySets
        .where((studySet) => studySet.languageCombinationId == value.id)
        .toList();

    final selectedStudySet = studySets.isNotEmpty ? studySets.first : null;

    await _configurationRepository.saveConfiguration(
      Configuration(
        id: 1,
        currentLanguagePairId: value.id,
        currentStudySetId: selectedStudySet?.id,
      ),
    );

    if (!mounted) return;
    setState(() {
      _selectedLanguagePair = value;
      _studySets = studySets;
      _selectedStudySet = selectedStudySet;
    });
  }

  Future<void> _exportStudySet() async {
    final studySet = _selectedStudySet;
    if (studySet?.id == null) {
      await _showMessage('Select a Study Set before exporting.');
      return;
    }

    final filePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Study Set',
      fileName: 'vocabulary_trainer_study_set.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );

    if (filePath == null) return;

    await _runBusy(() async {
      await _transferService.exportStudySet(
        studySetId: studySet!.id!,
        filePath: filePath,
      );
    });

    if (!mounted) return;
    await _showMessage('Study Set exported successfully.');
  }

  Future<void> _chooseStudySetImportFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Study Set Transfer',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: false,
    );

    if (result == null || result.files.single.path == null) return;

    final filePath = result.files.single.path!;
    await _prepareStudySetImportFromFile(filePath, null);
  }

  Future<void> _prepareStudySetImportFromFile(
    String filePath,
    TransferStudySetPackage? preDecodedPackage,
  ) async {
    try {
      final package = preDecodedPackage ??
          await _decodeStudySetFile(filePath);

      final allStudySets = await _studySetRepository.getAllStudySets();
      final matchingPairs = _languagePairs.where((pair) {
        return pair.sourceLanguage == package.languagePair.sourceLanguage &&
            pair.targetLanguage == package.languagePair.targetLanguage;
      }).toList();

      if (matchingPairs.isEmpty) {
        await _showMessage(
          'The transfer contains the Language Pair '
          '${package.languagePair.sourceLanguage} → '
          '${package.languagePair.targetLanguage}, but that Language Pair '
          'does not exist on this installation.',
        );
        return;
      }

      final pair = matchingPairs.first;
      final targetStudySets = allStudySets
          .where((studySet) => studySet.languageCombinationId == pair.id)
          .toList();

      if (targetStudySets.isEmpty) {
        await _showMessage(
          'No Study Set exists for ${pair.sourceLanguage} → '
          '${pair.targetLanguage}. Create a Study Set first.',
        );
        return;
      }

      if (!mounted) return;
      final currentTarget = _selectedStudySet;
      final preservedTarget = currentTarget != null &&
              currentTarget.languageCombinationId == pair.id &&
              targetStudySets.any((set) => set.id == currentTarget.id)
          ? targetStudySets.firstWhere((set) => set.id == currentTarget.id)
          : targetStudySets.first;
      setState(() {
        _selectedImportFileName = filePath.split('/').last;
        _selectedImportFilePath = filePath;
        _importLanguagePair = pair;
        _importTargetStudySets = targetStudySets;
        _importTargetStudySet = preservedTarget;
      });
    } on Exception catch (e) {
      await _showMessage(_friendlyExceptionMessage(e));
    }
  }

  Future<TransferStudySetPackage> _decodeStudySetFile(String filePath) async {
    final bytes = await _readFileBytes(filePath);
    final content = String.fromCharCodes(bytes);
    return _transferCodec.decodeStudySet(content);
  }

  Future<List<int>> _readFileBytes(String filePath) async {
    // file_picker does not provide a cross-platform full-file read API for a
    // path, so use dart:io here.
    final file = File(filePath);
    return file.readAsBytes();
  }

  Future<void> _importStudySet() async {
    final filePath = _selectedImportFilePath;
    final targetStudySet = _importTargetStudySet;

    if (filePath == null || targetStudySet?.id == null) {
      await _showMessage(
        'Select a Study Set Transfer file and a target Study Set first.',
      );
      return;
    }

    await _runBusy(() async {
      final plan = await _transferService.prepareStudySetImport(
        filePath: filePath,
        targetStudySetId: targetStudySet!.id!,
      );

      final resolvedTargets = <String, String>{};
      for (final conflict in plan.contentConflicts) {
        final resolution = await _resolveConflict(conflict);
        if (resolution == null) {
          throw const TransferValidationException(
            'The Transfer was cancelled during conflict resolution.',
          );
        }
        resolvedTargets[_conflictKey(conflict.importedItem)] = resolution;
      }

      var allowHistoryOverwrite = false;
      if (plan.learningHistoryWillBeOverwritten) {
        allowHistoryOverwrite =
            await _showLearningHistoryOverwriteWarning();
        if (!allowHistoryOverwrite) {
          throw const TransferValidationException(
            'The Transfer was cancelled because existing learning information '
            'was not permitted to be overwritten.',
          );
        }
      }

      await _transferService.applyStudySetImport(
        filePath: filePath,
        targetStudySetId: targetStudySet.id!,
        resolvedTargetExpressions: resolvedTargets,
        allowLearningHistoryOverwrite: allowHistoryOverwrite,
      );

      if (!mounted) return;
      await _showMessage(
        'Study Set Transfer completed.\n\n'
        '${plan.newItems.length} new Vocabulary Items\n'
        '${plan.exactMatches.length} existing Vocabulary Items reused\n'
        '${plan.contentConflicts.length} content conflicts resolved',
      );
    });
  }

  Future<void> _exportEverything() async {
    final confirmed = await _showConfirmation(
      title: 'Transfer Everything',
      message:
          'This exports the complete vocabulary environment, including '
          'Language Pairs, Study Sets, Study Set memberships, learning history, '
          'and Study Set settings.',
    );
    if (!confirmed) return;

    final filePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Everything',
      fileName: 'vocabulary_trainer_everything.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );

    if (filePath == null) return;

    await _runBusy(() async {
      await _transferService.exportEverything(filePath: filePath);
    });

    if (!mounted) return;
    await _showMessage('Complete database exported successfully.');
  }

  Future<void> _importEverything() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Complete Transfer',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: false,
    );
    if (result == null || result.files.single.path == null) return;

    final filePath = result.files.single.path!;

    final confirmed = await _showConfirmation(
      title: 'Transfer Everything',
      message:
          'Transfer Everything is intended for a new or empty installation. '
          'The target environment must contain no learner data. Continue?',
    );
    if (!confirmed) return;

    await _runBusy(() async {
      await _transferService.importEverything(filePath: filePath);
    });

    if (!mounted) return;
    await _showMessage(
      'Complete database imported successfully.\n\n'
      'Return to the Learning Center to view the transferred environment.',
    );
  }

  Future<String?> _resolveConflict(TransferContentConflict conflict) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Resolve Transfer Conflict'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Source'),
                  const SizedBox(height: 4),
                  Text(
                    conflict.importedItem.sourceExpression,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  const Text('Existing Target'),
                  const SizedBox(height: 4),
                  Text(
                    conflict.existingTargetExpression,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  const Text('Imported Target'),
                  const SizedBox(height: 4),
                  Text(
                    conflict.importedItem.targetExpression,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Target Expression',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(dialogContext)
                    .pop(conflict.existingTargetExpression),
                child: const Text('Adopt Existing'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(dialogContext)
                    .pop(conflict.importedItem.targetExpression),
                child: const Text('Adopt Imported'),
              ),
              FilledButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isEmpty) return;
                  Navigator.of(dialogContext).pop(value);
                },
                child: const Text('Use Edited Target'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<bool> _showLearningHistoryOverwriteWarning() async {
    return _showConfirmation(
      title: 'Learning Information Will Be Replaced',
      message:
          'Existing learning information for transferred Vocabulary Items '
          'will be replaced by the learning information contained in the '
          'Transfer file. Continue?',
    );
  }

  Future<void> _runBusy(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } on Exception catch (e) {
      if (mounted) {
        await _showMessage(_friendlyExceptionMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmation({
    required String title,
    required String message,
  }) async {
    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _friendlyExceptionMessage(Exception exception) {
    if (exception is TransferValidationException) {
      return exception.message;
    }
    return exception.toString();
  }

  String _conflictKey(TransferVocabularyItemData item) =>
      '${item.languagePair.sourceLanguage}\u0000'
      '${item.languagePair.targetLanguage}\u0000'
      '${item.normalizedSourceExpression}';

  @override
  Widget build(BuildContext context) {
    final selectedPair = _selectedLanguagePair;
    final importPair = _importLanguagePair;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          switch (widget.mode) {
            TransferScreenMode.studySetExport => 'Transfer Study Set',
            TransferScreenMode.studySetImport => 'Import Study Set',
            TransferScreenMode.databaseExport => 'Transfer Database',
            TransferScreenMode.databaseImport => 'Import Database',
            TransferScreenMode.all => 'Transfer & Import',
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.mode == TransferScreenMode.all ||
                    widget.mode == TransferScreenMode.studySetExport ||
                    widget.mode == TransferScreenMode.studySetImport) ...[
                  Text(
                    widget.mode == TransferScreenMode.studySetImport
                        ? 'Import Study Set'
                        : 'Transfer Study Set',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.mode == TransferScreenMode.studySetImport
                        ? 'Import selected study set transfer file into target study set of this installation.'
                        : 'Move one Study Set to another installation. Other Study Set memberships are not transferred.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<LanguageCombination>(
                    value: selectedPair,
                    decoration: const InputDecoration(
                      labelText: 'Language Pair',
                      border: OutlineInputBorder(),
                    ),
                    items: _languagePairs.map((pair) {
                      return DropdownMenuItem(
                        value: pair,
                        child: Text('${pair.sourceLanguage} → ${pair.targetLanguage}'),
                      );
                    }).toList(),
                    onChanged: _busy ? null : _selectLanguagePair,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<StudySet>(
                    value: _selectedStudySet,
                    decoration: InputDecoration(
                      labelText: widget.mode == TransferScreenMode.studySetImport
                          ? 'Current Study Set'
                          : 'Study Set to Export',
                      border: const OutlineInputBorder(),
                    ),
                    items: _studySets.map((studySet) {
                      return DropdownMenuItem(
                        value: studySet,
                        child: Text(studySet.isDefaultStudySet ? '★ ${studySet.name}' : studySet.name),
                      );
                    }).toList(),
                    onChanged: _busy
                        ? null
                        : (value) async {
                            if (value == null) return;
                            await _configurationRepository.saveConfiguration(
                              Configuration(
                                id: 1,
                                currentLanguagePairId: _selectedLanguagePair?.id,
                                currentStudySetId: value.id,
                              ),
                            );
                            if (!mounted) return;
                            setState(() => _selectedStudySet = value);
                          },
                  ),
                  const SizedBox(height: 12),
                  if (widget.mode == TransferScreenMode.studySetImport) ...[
                    FilledButton(
                      onPressed: _busy ? null : _chooseStudySetImportFile,
                      child: const Text('Select Study Set Transfer File'),
                    ),
                    if (_selectedImportFileName != null) ...[
                      const SizedBox(height: 10),
                      Text('Selected file: $_selectedImportFileName'),
                      const SizedBox(height: 10),
                      Text(
                        importPair == null
                            ? ''
                            : 'Import Language Pair: ${importPair.sourceLanguage} → ${importPair.targetLanguage}',
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<StudySet>(
                        value: _importTargetStudySet,
                        decoration: const InputDecoration(
                          labelText: 'Target Study Set',
                          border: OutlineInputBorder(),
                        ),
                        items: _importTargetStudySets.map((studySet) {
                          return DropdownMenuItem(
                            value: studySet,
                            child: Text(
                              studySet.isDefaultStudySet
                                  ? '★ ${studySet.name}'
                                  : studySet.name,
                            ),
                          );
                        }).toList(),
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _importTargetStudySet = value),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: _busy ? null : _importStudySet,
                        child: const Text('Import Study Set'),
                      ),
                    ],
                  ] else ...[
                    FilledButton(
                      onPressed: _busy ? null : _exportStudySet,
                      child: const Text('Transfer Study Set'),
                    ),
                  ],
                ],
                if (widget.mode == TransferScreenMode.all) ...[
                  const SizedBox(height: 12),
                  if (_selectedImportFileName != null) ...[
                    Text('Selected file: $_selectedImportFileName'),
                    const SizedBox(height: 8),
                    Text(importPair == null ? '' : 'Import Language Pair: ${importPair.sourceLanguage} → ${importPair.targetLanguage}'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<StudySet>(
                      value: _importTargetStudySet,
                      decoration: const InputDecoration(
                        labelText: 'Target Study Set',
                        border: OutlineInputBorder(),
                      ),
                      items: _importTargetStudySets.map((studySet) {
                        return DropdownMenuItem(
                          value: studySet,
                          child: Text(studySet.isDefaultStudySet ? '★ ${studySet.name}' : studySet.name),
                        );
                      }).toList(),
                      onChanged: _busy ? null : (value) => setState(() => _importTargetStudySet = value),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _busy ? null : _importStudySet,
                      child: const Text('Import into Target Study Set'),
                    ),
                  ],
                ],
                if (widget.mode == TransferScreenMode.studySetExport) const SizedBox.shrink(),
                if (widget.mode == TransferScreenMode.all) ...[
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),
                ],
                if (widget.mode == TransferScreenMode.all ||
                    widget.mode == TransferScreenMode.databaseExport ||
                    widget.mode == TransferScreenMode.databaseImport) ...[
                  const Text(
                    'Transfer Database',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Transfer the complete vocabulary environment to or from a new or empty installation.',
                  ),
                  const SizedBox(height: 16),
                  if (widget.mode == TransferScreenMode.all ||
                      widget.mode == TransferScreenMode.databaseExport)
                    FilledButton(
                      onPressed: _busy ? null : _exportEverything,
                      child: const Text('Transfer Database'),
                    ),
                  if (widget.mode == TransferScreenMode.all) const SizedBox(height: 10),
                  if (widget.mode == TransferScreenMode.all ||
                      widget.mode == TransferScreenMode.databaseImport)
                    OutlinedButton(
                      onPressed: _busy ? null : _importEverything,
                      child: const Text('Import Database'),
                    ),
                ],
                if (_busy) ...[
                  const SizedBox(height: 20),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
