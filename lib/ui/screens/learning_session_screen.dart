import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/language_combination.dart';
import '../../domain/learning_state.dart';
import '../../domain/study_set.dart';
import '../../domain/vocabulary_item.dart';
import '../../learning_engine/learning_engine.dart';
import '../../repository/sqlite_study_set_repository.dart';
import '../../repository/sqlite_vocabulary_repository.dart';

class LearningSessionScreen extends StatefulWidget {
  const LearningSessionScreen({
    super.key,
    required this.languageCombination,
    required this.studySet,
    required this.initialIntensive,
  });

  final LanguageCombination languageCombination;
  final StudySet studySet;
  final bool initialIntensive;

  @override
  State<LearningSessionScreen> createState() => _LearningSessionScreenState();
}

class _LearningSessionScreenState extends State<LearningSessionScreen> {
  final LearningEngine _learningEngine = LearningEngine();
  final SQLiteStudySetRepository _studySetRepository =
      SQLiteStudySetRepository();
  final SQLiteVocabularyRepository _vocabularyRepository =
      SQLiteVocabularyRepository();

  late bool _intensive;
  late TextEditingController _learningWindowController;
  late TextEditingController _minimumIntervalController;
  late StudySet _studySet;

  List<VocabularyItem> _allItems = [];
  List<VocabularyItem> _learningWindow = [];
  final Set<int> _presentedIds = <int>{};
  final Set<int> _setAsideIds = <int>{};
  final List<int> _intensivePresentationHistory = <int>[];
  int _effectiveMinimumInterval = 0;

  VocabularyItem? _currentItem;
  bool _started = false;
  bool _answerRevealed = false;
  bool _busy = false;

  StandardLearningResponse? _standardResponse;
  IntensiveLearningResponse? _intensiveResponse;
  String? _message;

  @override
  void initState() {
    super.initState();
    _intensive = widget.initialIntensive;
    _studySet = widget.studySet;
    _learningWindowController = TextEditingController(
      text: (_intensive
              ? _studySet.intenseLearningWindowSize
              : _studySet.standardLearningWindowSize)
          .toString(),
    );
    _minimumIntervalController = TextEditingController(
      text: _studySet.minimumInterval.toString(),
    );
    _loadItems();
  }

  @override
  void dispose() {
    _learningWindowController.dispose();
    _minimumIntervalController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final items = await _learningEngine.loadStudySetItems(_studySet.id!);
    if (!mounted) return;
    setState(() {
      _allItems = items;
    });
  }

  int get _learningWindowSize =>
      int.tryParse(_learningWindowController.text.trim()) ?? 0;

  int get _minimumInterval =>
      int.tryParse(_minimumIntervalController.text.trim()) ?? 0;

  bool get _hasValidSettings =>
      _learningWindowSize > 0 && (!_intensive || _minimumInterval > 0);

  Future<void> _persistSettings() async {
    final updated = _studySet.copyWith(
      standardLearningWindowSize:
          _intensive ? _studySet.standardLearningWindowSize : _learningWindowSize,
      intenseLearningWindowSize:
          _intensive ? _learningWindowSize : _studySet.intenseLearningWindowSize,
      minimumInterval: _minimumInterval,
    );

    await _studySetRepository.updateStudySet(updated);
    _studySet = updated;
  }

  Future<bool> _validateAndPersistSettings() async {
    if (!_hasValidSettings) {
      if (!mounted) return false;
      setState(() {
        _message = 'Please enter a positive integer.';
      });
      return false;
    }

    await _persistSettings();
    return true;
  }

  Future<void> _startLearning() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });

    final valid = await _validateAndPersistSettings();
    if (!valid) {
      if (mounted) setState(() => _busy = false);
      return;
    }

    // Ensure the initial Learning Window is built from the complete current
    // Study Set rather than from a still-loading _allItems snapshot.
    await _loadItems();
    if (!mounted) return;

    _intensivePresentationHistory.clear();
    _effectiveMinimumInterval = _minimumInterval;

    final selected = _buildWindowForCurrentMode(
      excludedIds: _setAsideIds,
    );

    if (!mounted) return;
    setState(() {
      _learningWindow = selected;
      _started = true;
      _answerRevealed = false;
      _standardResponse = null;
      _intensiveResponse = null;
      _currentItem = _pickRandom(selected);
      if (_currentItem?.id != null) {
        _presentedIds.add(_currentItem!.id!);
        if (_intensive) {
          _intensivePresentationHistory.add(_currentItem!.id!);
        }
      }
      _busy = false;
      if (selected.isEmpty) {
        _message = 'There are no Vocabulary Items currently available for learning.';
      }
    });
  }

  void _returnToLearningCenter() {
    if (_busy || !mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _showAnswer() async {
    if (_currentItem == null) return;
    await _reconcileLearningWindowAfterSettingChange();
    if (!mounted) return;
    setState(() {
      _answerRevealed = true;
    });
  }

  Future<void> _editCurrentVocabulary() async {
    final item = _currentItem;
    if (item == null || item.id == null || !_answerRevealed || _busy) return;

    final sourceController = TextEditingController(
      text: item.sourceExpression,
    );
    final targetController = TextEditingController(
      text: item.targetExpression,
    );

    try {
      final studySets = await _studySetRepository
          .getStudySetsByLanguageCombinationId(widget.languageCombination.id!);
      final memberships = await _studySetRepository
          .getStudySetIdsForVocabularyItem(item.id!);

      // The Repository is structural and is not offered as a membership
      // checkbox. It remains the permanent home of every VocabularyItem.
      final editableStudySets = studySets
          .where((studySet) => !studySet.isDefaultStudySet)
          .toList();
      final selectedStudySetIds = memberships.toSet();

      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: const Text('Edit Vocabulary'),
                content: SizedBox(
                  width: 720,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 460),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: sourceController,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  labelText: 'Source',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: targetController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Target',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: const Text('Cancel'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: () async {
                                      final source = sourceController.text.trim();
                                      final target = targetController.text.trim();
                                      if (source.isEmpty || target.isEmpty) return;

                                      await _vocabularyRepository
                                          .updateVocabularyExpressions(
                                        item.id!,
                                        source,
                                        target,
                                      );

                                      final currentMemberships =
                                          await _studySetRepository
                                              .getStudySetIdsForVocabularyItem(
                                                  item.id!);
                                      final currentIds = currentMemberships.toSet();

                                      for (final studySetId in editableStudySets
                                          .map((studySet) => studySet.id)
                                          .whereType<int>()) {
                                        final shouldBelong =
                                            selectedStudySetIds.contains(studySetId);
                                        final currentlyBelongs =
                                            currentIds.contains(studySetId);

                                        if (shouldBelong && !currentlyBelongs) {
                                          await _studySetRepository
                                              .addVocabularyItemToStudySet(
                                            item.id!,
                                            studySetId,
                                          );
                                        } else if (!shouldBelong && currentlyBelongs) {
                                          await _studySetRepository
                                              .removeVocabularyItemFromStudySet(
                                            item.id!,
                                            studySetId,
                                          );
                                        }
                                      }

                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext, true);
                                      }
                                    },
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Study Sets',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: editableStudySets.isEmpty
                                    ? const Align(
                                        alignment: Alignment.topLeft,
                                        child: Text(
                                          'No user-defined Study Sets available.',
                                        ),
                                      )
                                    : SingleChildScrollView(
                                        child: Column(
                                          children: editableStudySets.map((studySet) {
                                            final studySetId = studySet.id;
                                            return CheckboxListTile(
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                              controlAffinity:
                                                  ListTileControlAffinity.leading,
                                              value: studySetId != null &&
                                                  selectedStudySetIds
                                                      .contains(studySetId),
                                              title: Text(
                                                studySet.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              onChanged: studySetId == null
                                                  ? null
                                                  : (checked) {
                                                      setDialogState(() {
                                                        if (checked == true) {
                                                          selectedStudySetIds
                                                              .add(studySetId);
                                                        } else {
                                                          selectedStudySetIds
                                                              .remove(studySetId);
                                                        }
                                                      });
                                                    },
                                            );
                                          }).toList(),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              );
            },
          );
        },
      );

      if (!mounted || saved != true || item.id == null) return;

      final refreshed =
          await _vocabularyRepository.getVocabularyItemById(item.id!);
      if (!mounted || refreshed == null) return;

      setState(() {
        _currentItem = refreshed;
      });
    } finally {
      // The dialog route may still be completing its gesture/transition when
      // showDialog returns. Dispose the controllers after the next frame so
      // no TextField can receive a final gesture using a disposed controller.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        sourceController.dispose();
        targetController.dispose();
      });
    }
  }

  Future<void> _next() async {
    if (_currentItem == null || _busy) return;
    await _reconcileLearningWindowAfterSettingChange();
    if (!mounted) return;
    // Standard Learning requires an educational response before Next.
    // Intensive Learning does not: Done for now is optional, while Next
    // means continue to the next Vocabulary Item without setting this one aside.
    if (!_intensive && _standardResponse == null) {
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    if (_intensive) {
      if (_intensiveResponse == IntensiveLearningResponse.doneForNow) {
        await _learningEngine.commitIntensiveResponse(
          item: _currentItem!,
          response: _intensiveResponse!,
        );
        if (_currentItem!.id != null) {
          _setAsideIds.add(_currentItem!.id!);
        }
      }
    } else {
      await _learningEngine.commitStandardResponse(
        item: _currentItem!,
        response: _standardResponse!,
      );
    }

    await _loadItems();

    List<VocabularyItem> nextCandidates;
    VocabularyItem? nextItem;

    if (_intensive) {
      _learningWindow = _learningWindow
          .where((item) => item.id != _currentItem!.id)
          .toList();

      if (_intensiveResponse == IntensiveLearningResponse.doneForNow &&
          _currentItem!.id != null) {
        _setAsideIds.add(_currentItem!.id!);
      }

      _learningWindow = _refillIntensiveWindow(
        currentWindow: _learningWindow,
        excludedIds: _setAsideIds.union({_currentItem!.id!}),
      );
      nextCandidates = _selectIntensiveCandidates();
      nextItem = _pickRandom(nextCandidates);
    } else {
      _learningWindow = _learningEngine.refillLearningWindow(
        currentWindow: _learningWindow,
        allItems: _allItems,
        windowSize: max(1, _learningWindowSize),
        removedItemId: _currentItem!.id,
      );
      nextCandidates = List<VocabularyItem>.from(_learningWindow);
      nextItem = _pickRandom(nextCandidates);
    }

    if (!mounted) return;
    setState(() {
      _currentItem = nextItem;
      _answerRevealed = false;
      _standardResponse = null;
      _intensiveResponse = null;
      // Keep the complete runtime Learning Window. In Intensive Learning,
      // nextCandidates is only the subset satisfying the current Minimum
      // Interval used to choose the next item; it is not the window itself.
      if (nextItem?.id != null) {
        _presentedIds.add(nextItem!.id!);
        if (_intensive) {
          _intensivePresentationHistory.add(nextItem.id!);
        }
      }
      _busy = false;
      if (nextItem == null) {
        _message = 'There are no more eligible Vocabulary Items right now.';
      }
    });
  }

  List<VocabularyItem> _selectIntensiveCandidates() {
    final eligible = _learningWindow.where((item) {
      final id = item.id;
      if (id == null || _setAsideIds.contains(id)) return false;
      return item.learningState != LearningState.mastered &&
          item.learningState != LearningState.deferred;
    }).toList();

    if (eligible.isEmpty) return [];

    // Preserve the configured Minimum Interval whenever possible. If the
    // current pool is too small to satisfy it, reduce the effective interval
    // to the greatest value that actually permits at least one candidate.
    // The reduced value is runtime-only; the learner's configured setting is
    // not changed or persisted.
    for (var interval = max(0, _minimumInterval); interval >= 0; interval--) {
      final recent = interval == 0
          ? <int>{}
          : _intensivePresentationHistory
              .skip(max(0, _intensivePresentationHistory.length - interval))
              .toSet();

      final candidates = eligible
          .where((item) => !recent.contains(item.id))
          .toList();

      if (candidates.isNotEmpty) {
        _effectiveMinimumInterval = interval;
        return candidates;
      }
    }

    // Defensive fallback; with interval 0, every eligible item qualifies.
    _effectiveMinimumInterval = 0;
    return eligible;
  }

  List<VocabularyItem> _refillIntensiveWindow({
    required List<VocabularyItem> currentWindow,
    required Set<int> excludedIds,
  }) {
    final size = max(1, _learningWindowSize);
    final survivors = currentWindow
        .where((item) => item.id != null && !excludedIds.contains(item.id))
        .toList();
    if (survivors.length >= size) return survivors.take(size).toList();

    final existing = survivors.map((item) => item.id).whereType<int>().toSet();
    final additions = _allItems.where((item) {
      final id = item.id;
      if (id == null || existing.contains(id) || excludedIds.contains(id)) {
        return false;
      }
      return item.learningState != LearningState.mastered &&
          item.learningState != LearningState.deferred;
    }).toList()
      ..shuffle();

    return [...survivors, ...additions.take(size - survivors.length)];
  }

  List<VocabularyItem> _buildWindowForCurrentMode({
    Set<int> excludedIds = const <int>{},
  }) {
    if (_intensive) {
      final eligible = _allItems.where((item) {
        final id = item.id;
        if (id == null || excludedIds.contains(id)) return false;
        return item.learningState != LearningState.mastered &&
            item.learningState != LearningState.deferred;
      }).toList()
        ..shuffle();
      return eligible.take(max(0, _learningWindowSize)).toList();
    }

    return _learningEngine.selectLearningWindow(
      items: _allItems,
      windowSize: _learningWindowSize,
      excludedIds: excludedIds,
    );
  }

  VocabularyItem? _pickRandom(List<VocabularyItem> items) {
    if (items.isEmpty) return null;
    final copy = List<VocabularyItem>.from(items)..shuffle();
    return copy.first;
  }

  VocabularyItem? _selectFromCurrentWindow() {
    for (final item in _learningWindow) {
      if (item.id == null || !_presentedIds.contains(item.id)) {
        return item;
      }
    }
    return null;
  }

  Future<void> _switchMode(bool intensive) async {
    if (intensive == _intensive || _busy) return;

    final previousMode = _intensive;
    if (previousMode) {
      _studySet = _studySet.copyWith(
        intenseLearningWindowSize: _learningWindowSize,
        minimumInterval: _minimumInterval,
      );
    } else {
      _studySet = _studySet.copyWith(
        standardLearningWindowSize: _learningWindowSize,
      );
    }
    await _studySetRepository.updateStudySet(_studySet);

    final abandonedItemId = _currentItem?.id;
    _setAsideIds.clear();
    _intensivePresentationHistory.clear();

    final nextStudySet = _studySet.copyWith();
    final nextWindowSize = intensive
        ? nextStudySet.intenseLearningWindowSize
        : nextStudySet.standardLearningWindowSize;

    setState(() {
      _intensive = intensive;
      _studySet = nextStudySet;
      _learningWindowController.text = nextWindowSize.toString();
      _minimumIntervalController.text = _studySet.minimumInterval.toString();
      _standardResponse = null;
      _intensiveResponse = null;
      _answerRevealed = false;
      _currentItem = null;
      _learningWindow = [];
      _message = null;
    });

    if (!_started) return;

    await _loadItems();
    final selected = _buildWindowForCurrentMode(
      excludedIds: abandonedItemId == null ? const <int>{} : {abandonedItemId},
    );
    final nextItem = _pickRandom(selected);

    if (!mounted) return;
    setState(() {
      _learningWindow = selected;
      _currentItem = nextItem;
      if (nextItem?.id != null && _intensive) {
        _intensivePresentationHistory.add(nextItem!.id!);
      }
      if (nextItem == null) {
        _message = 'There are no Vocabulary Items currently available for learning.';
      }
    });
  }

  Future<void> _reconcileLearningWindowAfterSettingChange() async {
    if (!_started || _busy) return;

    final valid = await _validateAndPersistSettings();
    if (!valid) return;

    final currentId = _currentItem?.id;
    final current = currentId == null
        ? <VocabularyItem>[]
        : _learningWindow.where((item) => item.id == currentId).toList();

    if (_learningWindowSize <= 0) return;

    if (_learningWindow.length > _learningWindowSize) {
      // Shrinking the runtime window should not arbitrarily discard review
      // items whose timestamps have already expired. Preserve the current
      // item, then preserve eligible expired review items by timestamp
      // priority, and fill any remaining capacity randomly from the other
      // admitted items.
      final now = DateTime.now();
      final others = _learningWindow
          .where((item) => item.id != currentId)
          .toList();
      final expired = others
          .where((item) =>
              item.learningTimestamp != null &&
              !item.learningTimestamp!.isAfter(now) &&
              item.learningState != LearningState.mastered &&
              item.learningState != LearningState.deferred)
          .toList()
        ..sort((a, b) => a.learningTimestamp!.compareTo(b.learningTimestamp!));
      final nonExpired = others.where((item) => !expired.contains(item)).toList()
        ..shuffle();

      final keepCount = max(0, _learningWindowSize - current.length);
      final retained = <VocabularyItem>[];
      retained.addAll(expired.take(keepCount));
      if (retained.length < keepCount) {
        retained.addAll(nonExpired.take(keepCount - retained.length));
      }
      _learningWindow = [...current, ...retained];
    } else {
      // Preserve the items already admitted to the runtime window. A settings
      // change does not mean that the current window should be reconstructed
      // from outside the window. Only Set Aside items are excluded from an
      // Intensive refill; existing window members remain admitted.
      _learningWindow = _intensive
          ? _refillIntensiveWindow(
              currentWindow: _learningWindow,
              excludedIds: _setAsideIds,
            )
          : _learningEngine.refillLearningWindow(
              currentWindow: _learningWindow,
              allItems: _allItems,
              windowSize: _learningWindowSize,
              removedItemId: null,
            );
    }

    if (mounted) setState(() {});
  }

  Future<void> _showLearningWindowDiagnostic() async {
    final diagnosticWindow = List<VocabularyItem>.from(_learningWindow);
    final diagnosticSize = _learningWindowSize;
    final diagnosticCurrentId = _currentItem?.id;
    final diagnosticMode = _intensive ? 'Intensive' : 'Standard';
    final diagnosticEffectiveInterval = _effectiveMinimumInterval;
    final diagnosticConfiguredInterval = _minimumInterval;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Learning Window — Developer Diagnostic'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mode: $diagnosticMode'),
                  Text('Window: ${diagnosticWindow.length} / $diagnosticSize'),
                  Text('Listed items: ${diagnosticWindow.length}'),
                  if (_intensive) ...[
                    Text('Configured Minimum Interval: $diagnosticConfiguredInterval'),
                    Text('Effective Minimum Interval: $diagnosticEffectiveInterval'),
                  ],
                  Text('Current Item: ${_currentItem?.sourceExpression ?? 'none'}'),
                  const SizedBox(height: 12),
                  const Text(
                    'Admitted items',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  if (diagnosticWindow.isEmpty)
                    const Text('Learning Window is empty.')
                  else
                    ...diagnosticWindow.asMap().entries.map((entry) {
                      final item = entry.value;
                      final timestamp = item.learningTimestamp == null
                          ? 'no timestamp'
                          : item.learningTimestamp!.toLocal().toString();
                      final current = item.id == diagnosticCurrentId ? '  ← current' : ' ';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${entry.key + 1}. ${item.sourceExpression} — ${item.learningState.name} — $timestamp$current',
                        ),
                      );
                    }),
                  if (_intensive) ...[
                    const SizedBox(height: 12),
                    Text('Set Aside: ${_setAsideIds.length}'),
                    Text('Presentation history: ${_intensivePresentationHistory.length}'),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSettingEditComplete() async {
    await _reconcileLearningWindowAfterSettingChange();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Session'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Return to Learning Center',
          onPressed: _returnToLearningCenter,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildContext(),
            const SizedBox(height: 12),
            _buildSettings(),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 180),
              child: _buildVocabularyArea(),
            ),
            if (_started && _answerRevealed) ...[
              const SizedBox(height: 12),
              _buildResponses(),
            ],
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 10),
            if (_started)
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: _busy ? null : _showLearningWindowDiagnostic,
                  child: const Text('Developer: Show Learning Window'),
                ),
              ),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: _busy ? null : _returnToLearningCenter,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Learning Center'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContext() {
    final label =
        '${widget.languageCombination.sourceLanguage} → '
        '${widget.languageCombination.targetLanguage}';
    final now = DateTime.now();
    var active = 0;
    var waiting = 0;
    var deferred = 0;
    var mastered = 0;

    for (final item in _allItems) {
      if (item.learningState == LearningState.mastered) {
        mastered++;
      } else if (item.learningState == LearningState.deferred) {
        deferred++;
      } else if (item.learningTimestamp != null &&
          item.learningTimestamp!.isAfter(now)) {
        waiting++;
      } else {
        active++;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${_studySet.name} (${_allItems.length} items)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                Text('Active: $active'),
                Text('Waiting: $waiting'),
                Text('Deferred: $deferred'),
                Text('Mastered: $mastered'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 20,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Learning Mode'),
            ChoiceChip(
              label: const Text('Standard'),
              selected: !_intensive,
              onSelected: (_) => _switchMode(false),
            ),
            ChoiceChip(
              label: const Text('Intensive'),
              selected: _intensive,
              onSelected: (_) => _switchMode(true),
            ),
            _numberField('Learning Window', _learningWindowController),
            if (_intensive)
              _numberField('Minimum Interval', _minimumIntervalController),
          ],
        ),
      ),
    );
  }

  Widget _numberField(
    String label,
    TextEditingController controller,
  ) {
    return SizedBox(
      width: 136,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        onEditingComplete: _handleSettingEditComplete,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildVocabularyArea() {
    if (!_started) {
      return Center(
        child: SizedBox(
          width: 220,
          child: ElevatedButton(
            onPressed: _busy ? null : _startLearning,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Start Learning',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      );
    }

    final item = _currentItem;
    if (item == null) {
      return const Center(child: Text('No vocabulary available.'));
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.sourceExpression,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          if (_answerRevealed) ...[
            const SizedBox(height: 24),
            Text(
              item.targetExpression,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _busy ? null : _editCurrentVocabulary,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit Vocabulary'),
            ),
          ],
          const SizedBox(height: 32),
          if (!_answerRevealed)
            ElevatedButton(
              onPressed: _showAnswer,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 34, vertical: 16),
                child: Text('Show Answer'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResponses() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_intensive)
              _responseChip(
                label: 'Done for now',
                selected: _intensiveResponse != null,
                onSelected: (_) {
                  setState(() {
                    _intensiveResponse =
                        _intensiveResponse ==
                                IntensiveLearningResponse.doneForNow
                            ? null
                            : IntensiveLearningResponse.doneForNow;
                  });
                },
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _standardChip('10 minutes', StandardLearningResponse.minutes10),
                  _standardChip('30 minutes', StandardLearningResponse.minutes30),
                  _standardChip('2 hours', StandardLearningResponse.hours2),
                  _standardChip('2 days', StandardLearningResponse.days2),
                  _standardChip('2 weeks', StandardLearningResponse.weeks2),
                  _standardChip('2 months', StandardLearningResponse.months2),
                ],
              ),
              const Divider(height: 20),
              Wrap(
                spacing: 8,
                children: [
                  _standardChip('Mastered', StandardLearningResponse.mastered),
                  _standardChip('Deferred', StandardLearningResponse.deferred),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: 180,
                child: ElevatedButton(
                  onPressed: (_intensive
                              ? true
                              : _standardResponse != null) &&
                          !_busy
                      ? _next
                      : null,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('Next'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _standardChip(String label, StandardLearningResponse response) {
    return _responseChip(
      label: label,
      selected: _standardResponse == response,
      onSelected: (_) {
        setState(() {
          _standardResponse = response;
        });
      },
    );
  }

  Widget _responseChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
    );
  }
}
