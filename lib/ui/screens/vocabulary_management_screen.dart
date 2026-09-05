import 'package:flutter/material.dart';

import '../../domain/vocabulary_item.dart';
import '../../domain/learning_state.dart';
import '../../domain/study_set.dart';
import '../../repository/sqlite_configuration_repository.dart';
import '../../repository/sqlite_study_set_repository.dart';
import '../../repository/sqlite_vocabulary_repository.dart';
import 'package:vocabulary_trainer/domain/configuration.dart';
import '../widgets/compact_dropdown.dart';

class VocabularyManagementScreen extends StatefulWidget {
  final int? initialVocabularyItemId;
  final int? resolveStudySetId;
  final String? resolveStudySetName;

  const VocabularyManagementScreen({
    super.key,
    this.initialVocabularyItemId,
    this.resolveStudySetId,
    this.resolveStudySetName,
  });

  @override
  State<VocabularyManagementScreen> createState() =>
      _VocabularyManagementScreenState();
}

class _VocabularyManagementScreenState
    extends State<VocabularyManagementScreen> {
  final SQLiteVocabularyRepository _vocabularyRepository =
      SQLiteVocabularyRepository();

  final SQLiteStudySetRepository _studySetRepository =
      SQLiteStudySetRepository();

  final SQLiteConfigurationRepository _configurationRepository =
      SQLiteConfigurationRepository();

  static const double _tableFontSize = 12;
  static const double _headerFontSize = 12;

  static const double _rowHorizontalPadding = 10;
  static const double _rowVerticalPadding = 3;
  static const double _headerVerticalPadding = 4;

  List<VocabularyItem> _vocabularyItems = [];

  List<StudySet> _studySets = [];

  StudySet? _currentStudySetFilter;

  Set<int> _visibleVocabularyItemIds = {};

  final Map<int, Set<int>> _studySetMemberships = {};

  final Set<int> _selectedVocabularyItemIds = {};

  bool _selectionMode = false;

  bool _studySetMode = false;

  final TextEditingController _searchController = TextEditingController();

  String _stateFilter = 'All States';

  int get _selectionCount => _selectedVocabularyItemIds.length;

  String _defaultStudySetLabel() {
    for (final studySet in _studySets) {
      if (studySet.isDefaultStudySet) {
        return '★ ${studySet.name}';
      }
    }
    return '★ Repository';
  }

  bool _isSelected(int? vocabularyItemId) {
    return vocabularyItemId != null &&
        _selectedVocabularyItemIds.contains(vocabularyItemId);
  }

  Iterable<VocabularyItem> get _selectedVocabularyItems =>
      _vocabularyItems.where((item) => _isSelected(item.id));

  List<VocabularyItem> get _visibleVocabularyItems {
    final searchText = _searchController.text.trim().toLowerCase();

    return _vocabularyItems.where((item) {
      if (_currentStudySetFilter != null &&
          !_visibleVocabularyItemIds.contains(item.id)) {
        return false;
      }

      if (searchText.isNotEmpty) {
        final source = item.sourceExpression.toLowerCase();
        final target = item.targetExpression.toLowerCase();
        if (!source.contains(searchText) && !target.contains(searchText)) {
          return false;
        }
      }

      if (_stateFilter != 'All States' &&
          _learningStateLabel(item) != _stateFilter) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadVocabulary();
  }

  Future<void> _loadVocabulary() async {
    final configuration = await _configurationRepository.getConfiguration();

    if (configuration == null || configuration.currentLanguagePairId == null) {
      return;
    }

    final vocabulary = await _vocabularyRepository
        .getVocabularyItemsByLanguageCombinationId(
          configuration.currentLanguagePairId!,
        );

    final studySets = await _studySetRepository
        .getStudySetsByLanguageCombinationId(
          configuration.currentLanguagePairId!,
        );

    _vocabularyItems = vocabulary;
    await _loadStudySetMemberships();

    if (!mounted) return;

    setState(() {
      _studySets = studySets;

      if (_currentStudySetFilter == null && studySets.isNotEmpty) {
        _currentStudySetFilter = studySets.firstWhere(
          (studySet) => studySet.id == configuration.currentStudySetId,
          orElse: () => studySets.first,
        );
      }

      if (_currentStudySetFilter != null) {
        _visibleVocabularyItemIds = _studySetMemberships.entries
            .where(
              (entry) => entry.value.contains(_currentStudySetFilter!.id),
            )
            .map((entry) => entry.key)
            .toSet();
      } else {
        _visibleVocabularyItemIds = {};
      }

      if (_selectedVocabularyItemIds.isNotEmpty) {
        final selectedId = _selectedVocabularyItemIds.first;

        if (!vocabulary.any((item) => item.id == selectedId)) {
          _selectedVocabularyItemIds.clear();
        }
      }
    });

    final initialId = widget.initialVocabularyItemId;
    if (initialId != null) {
      VocabularyItem? initialItem;
      for (final item in vocabulary) {
        if (item.id == initialId) {
          initialItem = item;
          break;
        }
      }
      if (initialItem != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showEditDialog(
            initialItem!,
            resolveStudySetId: widget.resolveStudySetId,
            resolveStudySetName: widget.resolveStudySetName,
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showEditDialog(
    VocabularyItem vocabularyItem, {
    int? resolveStudySetId,
    String? resolveStudySetName,
  }) async {
    final sourceController = TextEditingController(
      text: vocabularyItem.sourceExpression,
    );

    final targetController = TextEditingController(
      text: vocabularyItem.targetExpression,
    );

    bool addToResolveStudySet = resolveStudySetId != null;
    bool saved = false;

    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Vocabulary'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 70, child: Text('Source:')),
                        Expanded(
                          child: TextField(
                            controller: sourceController,
                            autofocus: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const SizedBox(width: 70, child: Text('Target:')),
                        Expanded(
                          child: TextField(controller: targetController),
                        ),
                      ],
                    ),
                    if (resolveStudySetId != null) ...[
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: addToResolveStudySet,
                        onChanged: (value) {
                          setDialogState(() {
                            addToResolveStudySet = value ?? false;
                          });
                        },
                        title: Text(
                          'Add to ${resolveStudySetName ?? 'this Study Set'}',
                        ),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final sourceExpression = sourceController.text.trim();
                    final targetExpression = targetController.text.trim();

                    await _vocabularyRepository.updateVocabularyExpressions(
                      vocabularyItem.id!,
                      sourceExpression,
                      targetExpression,
                    );

                    if (resolveStudySetId != null && addToResolveStudySet) {
                      await _studySetRepository.addVocabularyItemToStudySet(
                        vocabularyItem.id!,
                        resolveStudySetId,
                      );
                    }

                    saved = true;
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    sourceController.dispose();
    targetController.dispose();

    if (saved && mounted) {
      await _loadVocabulary();
    }
  }

  Future<void> _applyLearningStateToSelectedItems(
    LearningState state,
    String actionLabel,
  ) async {
    if (_selectionCount == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final itemLabel = _selectionCount == 1
            ? 'the selected vocabulary item'
            : 'the $_selectionCount selected vocabulary items';

        return AlertDialog(
          title: Text(actionLabel),
          content: Text('$actionLabel $itemLabel?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(actionLabel.replaceAll('...', '')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final timestamp = DateTime.now();

    for (final item in _selectedVocabularyItems.toList()) {
      await _vocabularyRepository.updateVocabularyItem(
        VocabularyItem(
          id: item.id,
          languageCombinationId: item.languageCombinationId,
          sourceExpression: item.sourceExpression,
          targetExpression: item.targetExpression,
          learningState: state,
          learningTimestamp: state == LearningState.newItem
              ? null
              : timestamp,
        ),
      );
    }

    _selectedVocabularyItemIds.clear();
    _selectionMode = false;

    await _loadVocabulary();
  }

  Future<void> _showCreateDialog() async {
    final sourceController = TextEditingController();
    final targetController = TextEditingController();
    bool addToCurrentStudySet =
        _currentStudySetFilter != null && !_currentStudySetFilter!.isDefaultStudySet;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentStudySet = _currentStudySetFilter;
            return AlertDialog(
              title: const Text('Create Vocabulary'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 70, child: Text('Source:')),
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: sourceController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const SizedBox(width: 70, child: Text('Target:')),
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: targetController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      currentStudySet == null
                          ? 'Study Set: ${_defaultStudySetLabel()}'
                          : 'Study Set: ${currentStudySet.isDefaultStudySet ? '★ ${currentStudySet.name}' : currentStudySet.name}',
                    ),
                  ),
                  if (currentStudySet != null && !currentStudySet.isDefaultStudySet)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Add to this Study Set'),
                      value: addToCurrentStudySet,
                      onChanged: (value) {
                        setDialogState(() {
                          addToCurrentStudySet = value ?? false;
                        });
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final sourceExpression = sourceController.text.trim();
                    final targetExpression = targetController.text.trim();

                    if (sourceExpression.isEmpty || targetExpression.isEmpty) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('Source and Target are required.'),
                        ),
                      );
                      return;
                    }

                    final configuration =
                        await _configurationRepository.getConfiguration();
                    if (configuration?.currentLanguagePairId == null) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('No Language Pair is currently selected.'),
                        ),
                      );
                      return;
                    }

                    final languagePairId = configuration!.currentLanguagePairId!;
                    final exists = await _vocabularyRepository.sourceExpressionExists(
                      languagePairId,
                      sourceExpression,
                    );

                    if (exists) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'A vocabulary item with this Source already exists.',
                          ),
                        ),
                      );
                      return;
                    }

                    final vocabularyItem = VocabularyItem(
                      languageCombinationId: languagePairId,
                      sourceExpression: sourceExpression,
                      targetExpression: targetExpression,
                      learningState: LearningState.newItem,
                      learningTimestamp: null,
                    );

                    final vocabularyItemId =
                        await _vocabularyRepository.insertVocabularyItem(
                      vocabularyItem,
                    );

                    final repositoryStudySet = _studySets.firstWhere(
                      (studySet) => studySet.isDefaultStudySet,
                      orElse: () => throw StateError(
                        'Repository Study Set not found for current Language Pair.',
                      ),
                    );

                    // Every vocabulary item belongs to the Repository.
                    if (repositoryStudySet.id != null) {
                      await _studySetRepository.addVocabularyItemToStudySet(
                        vocabularyItemId,
                        repositoryStudySet.id!,
                      );
                    }

                    if (addToCurrentStudySet && currentStudySet?.id != null) {
                      await _studySetRepository.addVocabularyItemToStudySet(
                        vocabularyItemId,
                        currentStudySet!.id!,
                      );
                    }

                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    await _loadVocabulary();
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    sourceController.dispose();
    targetController.dispose();
  }

  Future<void> _deleteSelectedVocabularyItems() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete'),
          content: Text(
            _selectionCount == 1
                ? 'Delete the selected vocabulary item?\n\n'
                      'This action cannot be undone.'
                : 'Delete the $_selectionCount selected vocabulary items?\n\n'
                      'This action cannot be undone.',
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

    if (confirmed != true) {
      return;
    }

    for (final item in _selectedVocabularyItems) {
      await _vocabularyRepository.deleteVocabularyItem(item.id!);
    }

    _selectedVocabularyItemIds.clear();
    _selectionMode = false;

    await _loadVocabulary();
  }

  void _clearSelection() {
    _selectedVocabularyItemIds.clear();
    _selectionMode = false;
  }

  String _learningStateLabel(VocabularyItem item) {
    switch (item.learningState) {
      case LearningState.deferred:
        return 'Deferred';
      case LearningState.mastered:
        return 'Mastered';
      case LearningState.newItem:
        final timestamp = item.learningTimestamp;
        if (timestamp != null && timestamp.isAfter(DateTime.now())) {
          return 'Waiting';
        }
        return 'Active';
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _rowHorizontalPadding,
        vertical: _headerVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        border: Border(bottom: BorderSide(color: Colors.grey.shade500)),
      ),
      child: _studySetMode
          ? Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Source',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: _headerFontSize,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 5,
                  child: Text(
                    'Target',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: _headerFontSize,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      'State',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: _headerFontSize,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _defaultStudySetLabel(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: _headerFontSize,
                      ),
                    ),
                  ),
                ),
                ..._studySets
                    .where((studySet) => !studySet.isDefaultStudySet)
                    .map(
                      (studySet) => Expanded(
                        child: Center(
                          child: Text(
                            studySet.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: _headerFontSize,
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            )
          : const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Source',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: _headerFontSize,
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Text(
                    'Target',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: _headerFontSize,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      'State',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: _headerFontSize,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _loadStudySetMemberships() async {
    _studySetMemberships.clear();

    for (final item in _vocabularyItems) {
      if (item.id == null) continue;

      final studySetIds = await _studySetRepository
          .getStudySetIdsForVocabularyItem(item.id!);

      _studySetMemberships[item.id!] = studySetIds;
    }
  }

  Widget _buildVocabularyRow(VocabularyItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: InkWell(
        onTap: () {
          setState(() {
            if (_selectionMode) {
              if (_isSelected(item.id)) {
                _selectedVocabularyItemIds.remove(item.id);

                if (_selectedVocabularyItemIds.isEmpty) {
                  _selectionMode = false;
                }
              } else {
                _selectedVocabularyItemIds.add(item.id!);
              }
            } else {
              _selectedVocabularyItemIds
                ..clear()
                ..add(item.id!);
            }
          });
        },

        onLongPress: () {
          setState(() {
            _selectionMode = true;
            _selectedVocabularyItemIds.add(item.id!);
          });
        },

        child: Container(
          decoration: BoxDecoration(
            color: _isSelected(item.id) ? Colors.blue.shade50 : null,
            border: Border.all(
              color: _isSelected(item.id)
                  ? Colors.blue.shade700
                  : Colors.grey.shade300,
              width: _isSelected(item.id) ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: _rowHorizontalPadding,
            vertical: _rowVerticalPadding,
          ),
          child: _studySetMode
              ? Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        item.sourceExpression,
                        style: const TextStyle(fontSize: _tableFontSize),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Text(
                        item.targetExpression,
                        style: const TextStyle(fontSize: _tableFontSize),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          _learningStateLabel(item),
                          style: const TextStyle(fontSize: _tableFontSize),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '☑',
                          style: const TextStyle(fontSize: _tableFontSize),
                        ),
                      ),
                    ),
                    ..._studySets
                        .where((studySet) => !studySet.isDefaultStudySet)
                        .map(
                          (studySet) => Expanded(
                            child: Center(
                              child: InkWell(
                                onTap: () async {
                                  final memberships =
                                      _studySetMemberships[item.id!] ?? <int>{};

                                  if (memberships.contains(studySet.id)) {
                                    await _studySetRepository
                                        .removeVocabularyItemFromStudySet(
                                      item.id!,
                                      studySet.id!,
                                    );

                                    memberships.remove(studySet.id);
                                  } else {
                                    await _studySetRepository
                                        .addVocabularyItemToStudySet(
                                      item.id!,
                                      studySet.id!,
                                    );

                                    memberships.add(studySet.id!);
                                  }

                                  setState(() {
                                    _studySetMemberships[item.id!] =
                                        memberships;
                                  });
                                },
                                child: Text(
                                  (_studySetMemberships[item.id!] ?? <int>{})
                                          .contains(studySet.id)
                                      ? '☑'
                                      : '☐',
                                  style: const TextStyle(
                                    fontSize: _tableFontSize,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        item.sourceExpression,
                        style: const TextStyle(fontSize: _tableFontSize),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Text(
                        item.targetExpression,
                        style: const TextStyle(fontSize: _tableFontSize),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          _learningStateLabel(item),
                          style: const TextStyle(fontSize: _tableFontSize),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dropdownStudySets = <StudySet>[];
    final seenStudySetIds = <int>{};

    for (final studySet in _studySets) {
      final id = studySet.id;
      if (id != null && seenStudySetIds.add(id)) {
        dropdownStudySets.add(studySet);
      }
    }

    final selectedStudySetId = _currentStudySetFilter?.id;
    final dropdownValue = selectedStudySetId != null &&
            dropdownStudySets.any((studySet) => studySet.id == selectedStudySetId)
        ? selectedStudySetId
        : null;

    return PopScope(
      canPop: !_studySetMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !_studySetMode) return;

        setState(() {
          _studySetMode = false;
          _selectedVocabularyItemIds.clear();
          _selectionMode = false;
        });
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Vocabulary Management')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Study Set:'),
                    const SizedBox(width: 12),
                    CompactDropdown<int>(
                      value: dropdownValue,
                      items: dropdownStudySets.map((studySet) {
                        return DropdownMenuItem<int>(
                          value: studySet.id!,
                          child: Text(
                            studySet.isDefaultStudySet
                                ? '★ ${studySet.name}'
                                : studySet.name,
                          ),
                        );
                      }).toList(),
                      onChanged: (studySetId) async {
                        if (studySetId == null) return;

                        final studySet = dropdownStudySets.firstWhere(
                          (candidate) => candidate.id == studySetId,
                        );

                        final vocabularyItemIds = await _studySetRepository
                            .getVocabularyItemIdsForStudySet(studySet.id!);

                        final configuration = await _configurationRepository
                            .getConfiguration();

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

                        setState(() {
                          _currentStudySetFilter = studySet;
                          _visibleVocabularyItemIds = vocabularyItemIds.toSet();
                          _clearSelection();
                        });
                      },
                    ),
                  ],
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) {
                      setState(_clearSelection);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      hintText: 'Source or target',
                      isDense: true,
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('State:'),
                    const SizedBox(width: 12),
                    CompactDropdown<String>(
                      value: _stateFilter,
                      items: const [
                        DropdownMenuItem(
                          value: 'All States',
                          child: Text('All States'),
                        ),
                        DropdownMenuItem(
                          value: 'Active',
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(
                          value: 'Waiting',
                          child: Text('Waiting'),
                        ),
                        DropdownMenuItem(
                          value: 'Deferred',
                          child: Text('Deferred'),
                        ),
                        DropdownMenuItem(
                          value: 'Mastered',
                          child: Text('Mastered'),
                        ),
                      ],
                      onChanged: (state) {
                        if (state == null) return;
                        setState(() {
                          _stateFilter = state;
                          _clearSelection();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          _buildHeader(),

          Expanded(
            child: ListView.builder(
              itemCount: _visibleVocabularyItems.length,
              itemBuilder: (context, index) {
                return _buildVocabularyRow(_visibleVocabularyItems[index]);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(top: BorderSide(color: Colors.grey.shade400)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _studySetMode ? null : () async {
                    await _showCreateDialog();
                  },
                  child: const Text('Create...'),
                ),
                ElevatedButton(
                  onPressed: _selectionCount == 1
                      ? () async {
                          final vocabularyItem = _selectedVocabularyItems.first;

                          await _showEditDialog(vocabularyItem);
                        }
                      : null,
                  child: const Text('Edit...'),
                ),
                ElevatedButton(
                  onPressed: _selectionCount == 0
                      ? null
                      : () async {
                          await _deleteSelectedVocabularyItems();
                        },
                  child: const Text('Delete...'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _studySetMode = !_studySetMode;

                      if (_studySetMode) {
                        _selectedVocabularyItemIds.clear();
                        _selectionMode = false;
                      }
                    });
                  },
                  child: Text(
                    _studySetMode ? 'Done' : 'Manage Membership...',
                  ),
                ),
                ElevatedButton(
                  onPressed: _selectionCount == 0
                      ? null
                      : () async {
                          await _applyLearningStateToSelectedItems(
                            LearningState.deferred,
                            'Defer...',
                          );
                        },
                  child: const Text('Defer...'),
                ),
                ElevatedButton(
                  onPressed: _selectionCount == 0
                      ? null
                      : () async {
                          await _applyLearningStateToSelectedItems(
                            LearningState.mastered,
                            'Master...',
                          );
                        },
                  child: const Text('Master...'),
                ),
                ElevatedButton(
                  onPressed: _selectionCount == 0
                      ? null
                      : () async {
                          await _applyLearningStateToSelectedItems(
                            LearningState.newItem,
                            'Activate...',
                          );
                        },
                  child: const Text('Activate...'),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}
