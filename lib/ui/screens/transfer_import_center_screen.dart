import 'package:flutter/material.dart';

import '../../domain/configuration.dart';
import '../../domain/language_combination.dart';
import '../../domain/study_set.dart';
import '../../repository/sqlite_configuration_repository.dart';
import '../../repository/sqlite_language_combination_repository.dart';
import '../../repository/sqlite_study_set_repository.dart';
import 'transfer_screen.dart';
import 'vocabulary_import_screen.dart';

/// Central hub for all application-data import/export operations.
///
/// Database operations ignore the current Study Set selection. Study Set
/// operations use the current Language Pair / Study Set context.
class TransferImportCenterScreen extends StatefulWidget {
  const TransferImportCenterScreen({super.key});

  @override
  State<TransferImportCenterScreen> createState() =>
      _TransferImportCenterScreenState();
}

class _TransferImportCenterScreenState
    extends State<TransferImportCenterScreen> {
  final _languageRepository = SQLiteLanguageCombinationRepository();
  final _studySetRepository = SQLiteStudySetRepository();
  final _configurationRepository = SQLiteConfigurationRepository();

  List<LanguageCombination> _languagePairs = [];
  List<StudySet> _studySets = [];
  LanguageCombination? _selectedLanguagePair;
  StudySet? _selectedStudySet;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    final pairs = await _languageRepository.getAll();
    final allStudySets = await _studySetRepository.getAllStudySets();
    final configuration = await _configurationRepository.getConfiguration();

    LanguageCombination? selectedPair;
    StudySet? selectedStudySet;

    final currentPairId = configuration?.currentLanguagePairId;
    if (currentPairId != null) {
      for (final pair in pairs) {
        if (pair.id == currentPairId) {
          selectedPair = pair;
          break;
        }
      }
    }

    // Preserve the configured current Language Pair when possible. If there is
    // no valid configured pair, use the first available pair as the initial
    // context. The Study Set list must be filtered only after that fallback is
    // resolved.
    selectedPair ??= pairs.isNotEmpty ? pairs.first : null;

    final filteredSets = selectedPair == null
        ? <StudySet>[]
        : allStudySets
            .where((set) => set.languageCombinationId == selectedPair!.id)
            .toList();

    final currentStudySetId = configuration?.currentStudySetId;
    if (currentStudySetId != null) {
      for (final set in filteredSets) {
        if (set.id == currentStudySetId) {
          selectedStudySet = set;
          break;
        }
      }
    }

    selectedStudySet ??=
        filteredSets.isNotEmpty ? filteredSets.first : null;

    if (!mounted) return;
    setState(() {
      _languagePairs = pairs;
      _selectedLanguagePair = selectedPair;
      _studySets = filteredSets;
      _selectedStudySet = selectedStudySet;
      _loading = false;
    });
  }

  Future<void> _selectLanguagePair(LanguageCombination? value) async {
    if (value == null) return;

    final allStudySets = await _studySetRepository.getAllStudySets();
    final sets = allStudySets
        .where((set) => set.languageCombinationId == value.id)
        .toList();
    final selectedStudySet = sets.isNotEmpty ? sets.first : null;

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
      _studySets = sets;
      _selectedStudySet = selectedStudySet;
    });
  }

  Future<void> _selectStudySet(StudySet? value) async {
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
  }

  Future<void> _open(TransferScreenMode mode) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TransferScreen(mode: mode),
      ),
    );
    await _loadContext();
  }

  Future<void> _openImportStudySet() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const VocabularyImportScreen(),
      ),
    );
    await _loadContext();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transfer & Import')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final hasStudySetContext =
        _selectedLanguagePair != null && _selectedStudySet != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer & Import')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Database',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'These operations transfer the complete application environment. '
                  'The current Language Pair and Study Set are not relevant.',
                ),
                const SizedBox(height: 16),
                _OperationButton(
                  label: 'Transfer Database',
                  description: 'Export the complete application database.',
                  onPressed: () => _open(TransferScreenMode.databaseExport),
                ),
                const SizedBox(height: 10),
                _OperationButton(
                  label: 'Import Database',
                  description:
                      'Reconstruct the complete database in a new or empty installation.',
                  onPressed: () => _open(TransferScreenMode.databaseImport),
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),
                const Text(
                  'Study Set',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'These operations use the current Language Pair and Study Set. '
                  'The selected Study Set is the source for Transfer and the destination for Import.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<LanguageCombination>(
                  value: _selectedLanguagePair,
                  decoration: const InputDecoration(
                    labelText: 'Language Pair',
                    border: OutlineInputBorder(),
                  ),
                  items: _languagePairs.map((pair) {
                    return DropdownMenuItem(
                      value: pair,
                      child: Text(
                        '${pair.sourceLanguage} → ${pair.targetLanguage}',
                      ),
                    );
                  }).toList(),
                  onChanged: _selectLanguagePair,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<StudySet>(
                  value: _selectedStudySet,
                  decoration: const InputDecoration(
                    labelText: 'Study Set',
                    border: OutlineInputBorder(),
                  ),
                  items: _studySets.map((studySet) {
                    return DropdownMenuItem(
                      value: studySet,
                      child: Text(
                        studySet.isDefaultStudySet
                            ? '★ ${studySet.name}'
                            : studySet.name,
                      ),
                    );
                  }).toList(),
                  onChanged: _selectStudySet,
                ),
                const SizedBox(height: 16),
                _OperationButton(
                  label: 'Transfer Study Set',
                  description:
                      'Export the selected Study Set and its Vocabulary Items.',
                  onPressed: hasStudySetContext
                      ? () => _open(TransferScreenMode.studySetExport)
                      : null,
                ),
                const SizedBox(height: 10),
                _OperationButton(
                  label: 'Import Study Set',
                  description:
                      'Import vocabulary into the selected Study Set using the existing vocabulary-import workflow.',
                  onPressed: hasStudySetContext ? _openImportStudySet : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OperationButton extends StatelessWidget {
  const _OperationButton({
    required this.label,
    required this.description,
    required this.onPressed,
  });

  final String label;
  final String description;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(description),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton(
              onPressed: onPressed,
              child: const Text('Open'),
            ),
          ],
        ),
      ),
    );
  }
}
