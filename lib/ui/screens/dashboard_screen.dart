import 'package:flutter/material.dart';
import 'create_study_set_screen.dart';
import 'create_language_pair_screen.dart';
import '../../domain/language_combination.dart';
import '../../repository/sqlite_language_combination_repository.dart';
import '../../domain/configuration.dart';
import '../../repository/sqlite_configuration_repository.dart';
import '../../domain/study_set.dart';
import '../../repository/sqlite_study_set_repository.dart';
import 'transfer_import_center_screen.dart';
import 'vocabulary_management_screen.dart';
import 'developer_tools_screen.dart';
import 'learning_session_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SQLiteLanguageCombinationRepository _repository =
      SQLiteLanguageCombinationRepository();

  final SQLiteConfigurationRepository _configurationRepository =
      SQLiteConfigurationRepository();

  final SQLiteStudySetRepository _studySetRepository =
      SQLiteStudySetRepository();

  List<StudySet> _studySets = [];
  StudySet? _selectedStudySet;

  List<LanguageCombination> _languageCombinations = [];
  LanguageCombination? _selectedLanguageCombination;

  @override
  void initState() {
    super.initState();
    _loadLanguageCombinations();
  }

  Future<void> _loadLanguageCombinations() async {
    final combinations = await _repository.getAll();
    final allStudySets = await _studySetRepository.getAllStudySets();
    final configuration = await _configurationRepository.getConfiguration();

    LanguageCombination? selected;
    if (configuration?.currentLanguagePairId != null) {
      for (final combination in combinations) {
        if (combination.id == configuration!.currentLanguagePairId) {
          selected = combination;
          break;
        }
      }
    }

    selected ??= combinations.isNotEmpty ? combinations.first : null;

    final studySets = selected == null
        ? <StudySet>[]
        : allStudySets
            .where((studySet) => studySet.languageCombinationId == selected!.id)
            .toList();

    StudySet? selectedStudySet;
    if (configuration?.currentStudySetId != null) {
      for (final studySet in studySets) {
        if (studySet.id == configuration!.currentStudySetId) {
          selectedStudySet = studySet;
          break;
        }
      }
    }

    selectedStudySet ??= studySets.isEmpty
        ? null
        : studySets.firstWhere(
            (studySet) => studySet.isDefaultStudySet,
            orElse: () => studySets.first,
          );

    if (!mounted) return;

    setState(() {
      _languageCombinations = combinations;
      _selectedLanguageCombination = selected;
      _studySets = studySets;
      _selectedStudySet = selectedStudySet;
    });

    final contextLanguagePairId = selected?.id;
    final contextStudySetId = selectedStudySet?.id;
    if (contextLanguagePairId != configuration?.currentLanguagePairId ||
        contextStudySetId != configuration?.currentStudySetId) {
      await _configurationRepository.saveConfiguration(
        Configuration(
          id: configuration?.id ?? 1,
          currentLanguagePairId: contextLanguagePairId,
          currentStudySetId: contextStudySetId,
        ),
      );
    }

    await _refreshLearningAvailability();
  }

  Set<int> _allSelectedStudySetItemIds = <int>{};

  bool get _learningAvailable =>
      _selectedStudySet != null && _allSelectedStudySetItemIds.isNotEmpty;

  Future<void> _refreshLearningAvailability() async {
    final studySet = _selectedStudySet;
    if (studySet == null || studySet.id == null) {
      if (mounted) setState(() => _allSelectedStudySetItemIds = <int>{});
      return;
    }
    final ids = await _studySetRepository.getVocabularyItemIdsForStudySet(
      studySet.id!,
    );
    if (mounted) {
      setState(() => _allSelectedStudySetItemIds = ids.toSet());
    }
  }

  Future<void> _openLearning(bool intensive) async {
    if (!_learningAvailable || _selectedLanguageCombination == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LearningSessionScreen(
          languageCombination: _selectedLanguageCombination!,
          studySet: _selectedStudySet!,
          initialIntensive: intensive,
        ),
      ),
    );
    await _loadLanguageCombinations();
    await _refreshLearningAvailability();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learning Center')),
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
                      'Language Pair',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    SizedBox(
                      width: 280,
                      child: DropdownButton<LanguageCombination>(
                        value: _selectedLanguageCombination,
                        isExpanded: true,
                        items: _languageCombinations.map((combination) {
                        return DropdownMenuItem<LanguageCombination>(
                          value: combination,
                          child: Text(
                            '${combination.sourceLanguage} → ${combination.targetLanguage}',
                          ),
                        );
                        }).toList(),
                        onChanged: (value) async {
                          if (value == null) return;

                        final allStudySets =
                            await _studySetRepository.getAllStudySets();
                        final studySets = allStudySets
                            .where((studySet) =>
                                studySet.languageCombinationId == value.id)
                            .toList();

                        final selectedStudySet = studySets.isEmpty
                            ? null
                            : studySets.firstWhere(
                                (studySet) => studySet.isDefaultStudySet,
                                orElse: () => studySets.first,
                              );

                        setState(() {
                          _selectedLanguageCombination = value;
                          _studySets = studySets;
                          _selectedStudySet = selectedStudySet;
                        });

                        final configuration =
                            await _configurationRepository.getConfiguration();
                        await _configurationRepository.saveConfiguration(
                          Configuration(
                            id: configuration?.id ?? 1,
                            currentLanguagePairId: value.id,
                            currentStudySetId: selectedStudySet?.id,
                          ),
                        );
                        await _refreshLearningAvailability();
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Select Study Set',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    SizedBox(
                      width: 280,
                      child: DropdownButton<StudySet>(
                        value: _selectedStudySet,
                        isExpanded: true,
                        hint: const Text('No Study Set'),
                        items: _studySets.map((studySet) {
                          return DropdownMenuItem<StudySet>(
                            value: studySet,
                            child: Text(
                              studySet.isDefaultStudySet
                                  ? '★ ${studySet.name}'
                                  : studySet.name,
                            ),
                          );
                          }).toList(),
                        onChanged: (value) async {
                          if (value == null) return;

                          setState(() {
                            _selectedStudySet = value;
                          });

                          final configuration = await _configurationRepository
                              .getConfiguration();

                          if (configuration == null) return;

                          await _configurationRepository.saveConfiguration(
                            Configuration(
                              id: configuration.id,
                              currentLanguagePairId:
                                  configuration.currentLanguagePairId,
                              currentStudySetId: value.id,
                            ),
                          );
                          await _refreshLearningAvailability();
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    const SizedBox(height: 24),

                    if (_selectedStudySet != null && !_learningAvailable) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'The selected Study Set contains no Vocabulary Items.\n'
                        'Please import or create Vocabulary Items before beginning a Learning Session.',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                    ],

                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 180,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _learningAvailable
                                ? () => _openLearning(false)
                                : null,
                            child: const Text(
                              'Standard Learning',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _learningAvailable
                                ? () => _openLearning(true)
                                : null,
                            child: const Text(
                              'Intensive Learning',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 150,
                          child: OutlinedButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CreateStudySetScreen(),
                                ),
                              );

                              await _loadLanguageCombinations();
                            },
                            child: const Text('Study Sets'),
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: OutlinedButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const VocabularyManagementScreen(),
                                ),
                              );

                              await _loadLanguageCombinations();
                            },
                            child: const Text('Vocabulary'),
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: OutlinedButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const CreateLanguagePairScreen(),
                                ),
                              );

                              await _loadLanguageCombinations();
                            },
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Language Pairs'),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: OutlinedButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const TransferImportCenterScreen(),
                                ),
                              );

                              await _loadLanguageCombinations();
                            },
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Transfer & Import', maxLines: 1),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: OutlinedButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DeveloperToolsScreen(),
                                ),
                              );

                              await _loadLanguageCombinations();
                            },
                            child: const Text('Developer Tools'),
                          ),
                        ),
                      ],
                    ),
                  ], // children of inner Column
                ), // inner Column
              ), // inner Padding
            ), // Card
          ], // children of outer Column
        ), // outer Column
      ), // outer Padding
    ); // Scaffold
  }
}
