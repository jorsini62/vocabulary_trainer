import '../../repository/import_parser.dart';

import 'package:flutter/material.dart';

import '../../domain/language_combination.dart';
import '../../domain/study_set.dart';

import '../../repository/sqlite_language_combination_repository.dart';
import '../../repository/sqlite_configuration_repository.dart';
import '../../repository/sqlite_study_set_repository.dart';
import '../../repository/sqlite_vocabulary_repository.dart';

import '../../domain/configuration.dart';

import '../widgets/import_language_selector.dart';
import '../widgets/import_study_set_selector.dart';
import '../widgets/import_file_selector.dart';
import '../widgets/import_button.dart';

import 'package:file_picker/file_picker.dart';

import 'package:path/path.dart' as p;

import '../../domain/vocabulary_item.dart';
import '../../domain/learning_state.dart';

class VocabularyImportScreen extends StatefulWidget {
  const VocabularyImportScreen({super.key});

  @override
  State<VocabularyImportScreen> createState() => _VocabularyImportScreenState();
}

class _VocabularyImportScreenState extends State<VocabularyImportScreen> {
  final SQLiteLanguageCombinationRepository _languageRepository =
      SQLiteLanguageCombinationRepository();

  final SQLiteStudySetRepository _studySetRepository =
      SQLiteStudySetRepository();

  final SQLiteConfigurationRepository _configurationRepository =
      SQLiteConfigurationRepository();

  final ImportParser _importParser = ImportParser();

  final SQLiteVocabularyRepository _vocabularyRepository =
      SQLiteVocabularyRepository();

  List<LanguageCombination> _languageCombinations = [];
  List<StudySet> _studySets = [];

  LanguageCombination? _selectedLanguageCombination;
  StudySet? _selectedStudySet;

  String? _selectedFileName;
  String? _selectedFilePath;
  String? _importReport;
  final List<_DuplicateRecord> _duplicateRecords = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final languageCombinations = await _languageRepository.getAll();

    final configuration = await _configurationRepository.getConfiguration();

    LanguageCombination? selectedLanguageCombination;

    if (configuration != null) {
      for (final languageCombination in languageCombinations) {
        if (languageCombination.id == configuration.currentLanguagePairId) {
          selectedLanguageCombination = languageCombination;
          break;
        }
      }
    }

    selectedLanguageCombination ??= languageCombinations.isNotEmpty
        ? languageCombinations.first
        : null;

    List<StudySet> studySets = [];

    if (selectedLanguageCombination != null) {
      studySets = await _studySetRepository.getStudySetsByLanguageCombinationId(
        selectedLanguageCombination.id!,
      );
    }

    setState(() {
      _languageCombinations = languageCombinations;

      _selectedLanguageCombination = selectedLanguageCombination;

      _studySets = studySets;

      if (studySets.isNotEmpty) {
        final persistedStudySetId = configuration?.currentStudySetId;
        _selectedStudySet = studySets.firstWhere(
          (studySet) => studySet.id == persistedStudySetId,
          orElse: () => studySets.first,
        );
      } else {
        _selectedStudySet = null;
      }
    });
  }

  Future<void> _onLanguageCombinationChanged(
    LanguageCombination? languageCombination,
  ) async {
    if (languageCombination == null) {
      return;
    }

    await _configurationRepository.saveConfiguration(
      Configuration(
        id: 1,
        currentLanguagePairId: languageCombination.id,
        currentStudySetId: null,
      ),
    );

    final studySets = await _studySetRepository
        .getStudySetsByLanguageCombinationId(languageCombination.id!);

    setState(() {
      _selectedLanguageCombination = languageCombination;

      _studySets = studySets;

      _selectedStudySet = studySets.isNotEmpty ? studySets.first : null;
    });
  }

  Future<void> _onChooseFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
      initialDirectory: _selectedFilePath == null
          ? null
          : p.dirname(_selectedFilePath!),
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;

    setState(() {
      _selectedFileName = file.name;
      _selectedFilePath = file.path;
      _importReport = null;
      _duplicateRecords.clear();
    });
  }

  int _recordNumberFor(
    List<String> lines,
    String sourceExpression,
    String targetExpression,
  ) {
    var recordNumber = 0;
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      recordNumber++;

      final parts = rawLine.split('\t');
      if (parts.length >= 2 &&
          parts[0].trim() == sourceExpression.trim() &&
          parts[1].trim() == targetExpression.trim()) {
        return recordNumber;
      }
    }
    return 0;
  }

  Future<void> _onImport() async {
    if (_selectedFilePath == null ||
        _selectedLanguageCombination == null ||
        _selectedStudySet == null) {
      return;
    }

    try {
      final lines = await _importParser.readLines(_selectedFilePath!);
      final parsed = _importParser.parseLines(lines);

      var newItems = 0;
      var duplicates = 0;
      _duplicateRecords.clear();

      for (final item in parsed.items) {
        final vocabularyItemId =
            await _vocabularyRepository.getVocabularyItemIdBySourceExpression(
          _selectedLanguageCombination!.id!,
          item.sourceExpression,
        );

        if (vocabularyItemId == null) {
          final newVocabularyItemId =
              await _vocabularyRepository.insertVocabularyItem(
            VocabularyItem(
              languageCombinationId: _selectedLanguageCombination!.id!,
              sourceExpression: item.sourceExpression,
              targetExpression: item.targetExpression,
              learningState: LearningState.newItem,
              learningTimestamp: null,
            ),
          );

          final repositoryStudySet =
              await _studySetRepository.getDefaultStudySet(
            _selectedLanguageCombination!.id!,
          );

          if (repositoryStudySet == null) {
            throw Exception('Repository Study Set not found.');
          }

          await _studySetRepository.addVocabularyItemToStudySet(
            newVocabularyItemId,
            repositoryStudySet.id!,
          );

          await _studySetRepository.addVocabularyItemToStudySet(
            newVocabularyItemId,
            _selectedStudySet!.id!,
          );

          newItems++;
        } else {
          duplicates++;
          final existing = await _vocabularyRepository.getVocabularyItemById(
            vocabularyItemId,
          );

          if (existing != null) {
            final destinationMemberships =
                await _studySetRepository.getVocabularyItemIdsForStudySet(
              _selectedStudySet!.id!,
            );
            final alreadyInDestinationStudySet =
                destinationMemberships.contains(existing.id);

            _duplicateRecords.add(
              _DuplicateRecord(
                vocabularyItemId: existing.id!,
                sourceExpression: existing.sourceExpression,
                existingTargetExpression: existing.targetExpression,
                importedTargetExpression: item.targetExpression,
                resolveStudySetId: _selectedStudySet!.id!,
                resolveStudySetName: _selectedStudySet!.name,
                alreadyInDestinationStudySet: alreadyInDestinationStudySet,
                isExactDuplicate:
                    existing.targetExpression.trim() ==
                    item.targetExpression.trim(),
                recordNumber: _recordNumberFor(
                  lines,
                  item.sourceExpression,
                  item.targetExpression,
                ),
              ),
            );
          }
        }
      }

      final report = StringBuffer()
        ..writeln('Parsed: ${parsed.items.length}')
        ..writeln('New: $newItems')
        ..writeln('Duplicates: $duplicates')
        ..writeln('Errors: ${parsed.errors.length}');

      if (parsed.errors.isNotEmpty) {
        report.writeln();
        report.writeln('Validation Errors:');
        for (final error in parsed.errors) {
          report.writeln('• $error');
        }
      }

      if (!mounted) return;
      setState(() {
        _importReport = report.toString();
        _selectedFileName = null;
        _selectedFilePath = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _importReport = null;
        _duplicateRecords.clear();
      });

      String message;
      if (e is FormatException) {
        message =
            'Unsupported import file format.\n\n'
            'Supported formats:\n'
            '• UTF-8 tab-delimited text\n'
            '• UTF-16 Unicode text (Excel "Unicode Text").';
      } else {
        message = e.toString();
      }

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Failed'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _resolveDuplicate(_DuplicateRecord duplicate) async {
    if (duplicate.isExactDuplicate) {
      await _addExactDuplicateToStudySet(duplicate);
      return;
    }

    final sourceController = TextEditingController(
      text: duplicate.sourceExpression,
    );
    final targetController = TextEditingController();
    bool addToTargetStudySet = true;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Resolve Duplicate'),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Source',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(duplicate.sourceExpression),
                        const SizedBox(height: 14),
                        const Text(
                          'Existing Target',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(duplicate.existingTargetExpression),
                        const SizedBox(height: 12),
                        const Text(
                          'Imported Target',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(duplicate.importedTargetExpression),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                setDialogState(() {
                                  targetController.text =
                                      duplicate.existingTargetExpression;
                                });
                              },
                              child: const Text('Use Existing Target'),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: () {
                                setDialogState(() {
                                  targetController.text =
                                      duplicate.importedTargetExpression;
                                });
                              },
                              child: const Text('Use Imported Target'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: sourceController,
                          decoration:
                              const InputDecoration(labelText: 'Source'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: targetController,
                          decoration:
                              const InputDecoration(labelText: 'Target'),
                        ),
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: addToTargetStudySet,
                          onChanged: (value) {
                            setDialogState(() {
                              addToTargetStudySet = value ?? false;
                            });
                          },
                          title: Text(
                            'Add to ${duplicate.resolveStudySetName}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final source = sourceController.text.trim();
                      final target = targetController.text.trim();
                      if (source.isEmpty || target.isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Source and target expressions are required.',
                            ),
                          ),
                        );
                        return;
                      }

                      await _vocabularyRepository.updateVocabularyExpressions(
                        duplicate.vocabularyItemId,
                        source,
                        target,
                      );

                      if (addToTargetStudySet) {
                        await _studySetRepository.addVocabularyItemToStudySet(
                          duplicate.vocabularyItemId,
                          duplicate.resolveStudySetId,
                        );
                      }

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }

                      if (mounted) {
                        setState(() {
                          _duplicateRecords.removeWhere(
                            (item) =>
                                item.vocabularyItemId ==
                                duplicate.vocabularyItemId,
                          );
                        });
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      sourceController.dispose();
      targetController.dispose();
    }
  }

  void _doNotAddExactDuplicateToStudySet(_DuplicateRecord duplicate) {
    setState(() {
      _duplicateRecords.removeWhere(
        (item) => item.vocabularyItemId == duplicate.vocabularyItemId &&
            item.resolveStudySetId == duplicate.resolveStudySetId,
      );
    });
  }

  Future<void> _addExactDuplicateToStudySet(
    _DuplicateRecord duplicate,
  ) async {
    await _studySetRepository.addVocabularyItemToStudySet(
      duplicate.vocabularyItemId,
      duplicate.resolveStudySetId,
    );

    if (!mounted) return;

    setState(() {
      _duplicateRecords.removeWhere(
        (item) => item.vocabularyItemId == duplicate.vocabularyItemId,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added ${duplicate.sourceExpression} to ${duplicate.resolveStudySetName}.',
        ),
      ),
    );
  }

  Widget _buildDuplicateCard(_DuplicateRecord duplicate) {
    final recordLabel = duplicate.recordNumber > 0
        ? 'Record ${duplicate.recordNumber}'
        : 'Duplicate';

    final isExact = duplicate.isExactDuplicate;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Card(
          margin: const EdgeInsets.only(top: 8),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$recordLabel — ${isExact ? 'Already Exists' : 'Duplicate'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text('Source: ${duplicate.sourceExpression}'),
                Text('Existing target: ${duplicate.existingTargetExpression}'),
                if (!isExact)
                  Text(
                    'Imported target: ${duplicate.importedTargetExpression}',
                  ),
                if (isExact) ...[
                  const SizedBox(height: 6),
                  Text(
                    duplicate.alreadyInDestinationStudySet
                        ? 'Already in ${duplicate.resolveStudySetName}. No action required.'
                        : 'The vocabulary item can be added to ${duplicate.resolveStudySetName}.',
                  ),
                  const SizedBox(height: 8),
                  if (!duplicate.alreadyInDestinationStudySet)
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        TextButton(
                          onPressed: () => _addExactDuplicateToStudySet(duplicate),
                          child: Text('Add to ${duplicate.resolveStudySetName}'),
                        ),
                        TextButton(
                          onPressed: () => _doNotAddExactDuplicateToStudySet(duplicate),
                          child: const Text('Do not add to Study Set'),
                        ),
                      ],
                    ),
                ] else ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _resolveDuplicate(duplicate),
                    child: const Text('Resolve'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vocabulary Import')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ImportLanguageSelector(
              languageCombinations: _languageCombinations,
              selectedLanguageCombination: _selectedLanguageCombination,
              onChanged: _onLanguageCombinationChanged,
            ),
            const SizedBox(height: 20),
            ImportStudySetSelector(
              studySets: _studySets,
              selectedStudySet: _selectedStudySet,
              onChanged: (studySet) async {
                if (studySet == null) return;
                final configuration =
                    await _configurationRepository.getConfiguration();
                if (configuration != null) {
                  await _configurationRepository.saveConfiguration(
                    Configuration(
                      id: configuration.id,
                      currentLanguagePairId:
                          configuration.currentLanguagePairId,
                      currentStudySetId: studySet.id,
                    ),
                  );
                }
                if (!mounted) return;
                setState(() {
                  _selectedStudySet = studySet;
                });
              },
            ),
            const SizedBox(height: 20),
            ImportFileSelector(
              selectedFileName: _selectedFileName,
              onChooseFile: _onChooseFile,
              onClear: () {
                setState(() {
                  _selectedFileName = null;
                  _selectedFilePath = null;
                });
              },
            ),
            if (_importReport != null) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Import Results',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(_importReport!),
                        if (_duplicateRecords.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Duplicates',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          for (final duplicate in _duplicateRecords)
                            _buildDuplicateCard(duplicate),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (_importReport == null) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 220,
                  child: ImportButton(
                    enabled:
                        _selectedLanguageCombination != null &&
                        _selectedStudySet != null &&
                        _selectedFileName != null,
                    onPressed: _onImport,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DuplicateRecord {
  final int vocabularyItemId;
  final String sourceExpression;
  final String existingTargetExpression;
  final String importedTargetExpression;
  final int resolveStudySetId;
  final String resolveStudySetName;
  final bool alreadyInDestinationStudySet;
  final bool isExactDuplicate;
  final int recordNumber;

  const _DuplicateRecord({
    required this.vocabularyItemId,
    required this.sourceExpression,
    required this.existingTargetExpression,
    required this.importedTargetExpression,
    required this.resolveStudySetId,
    required this.resolveStudySetName,
    required this.alreadyInDestinationStudySet,
    required this.isExactDuplicate,
    required this.recordNumber,
  });
}
