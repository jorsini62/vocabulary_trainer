import 'dart:math';

import '../domain/learning_state.dart';
import '../domain/vocabulary_item.dart';
import '../repository/sqlite_study_set_repository.dart';
import '../repository/sqlite_vocabulary_repository.dart';

enum StandardLearningResponse {
  minutes10,
  minutes30,
  hours2,
  days2,
  weeks2,
  months2,
  mastered,
  deferred,
}

enum IntensiveLearningResponse { doneForNow }

class LearningEngine {
  final SQLiteVocabularyRepository _vocabularyRepository =
      SQLiteVocabularyRepository();
  final SQLiteStudySetRepository _studySetRepository =
      SQLiteStudySetRepository();
  final Random _random = Random();

  Future<List<VocabularyItem>> loadStudySetItems(int studySetId) async {
    final ids = await _studySetRepository.getVocabularyItemIdsForStudySet(studySetId);
    if (ids.isEmpty) return [];
    final set = await _studySetRepository.getStudySetById(studySetId);
    if (set == null) return [];
    final all = await _vocabularyRepository
        .getVocabularyItemsByLanguageCombinationId(set.languageCombinationId);
    final wanted = ids.toSet();
    return all.where((item) => item.id != null && wanted.contains(item.id)).toList();
  }

  List<VocabularyItem> selectLearningWindow({
    required List<VocabularyItem> items,
    required int windowSize,
    Set<int> excludedIds = const <int>{},
  }) {
    final size = max(0, windowSize);
    if (size == 0) return [];
    final now = DateTime.now();

    final review = items.where((item) {
      final id = item.id;
      if (id == null || excludedIds.contains(id)) return false;
      if (item.learningState == LearningState.mastered ||
          item.learningState == LearningState.deferred) return false;
      final ts = item.learningTimestamp;
      return ts != null && !ts.isAfter(now);
    }).toList()
      ..sort((a, b) {
        final c = a.learningTimestamp!.compareTo(b.learningTimestamp!);
        return c != 0 ? c : (a.id ?? 0).compareTo(b.id ?? 0);
      });

    final reviewTake = review.take(size).toList();
    if (reviewTake.length == size) return reviewTake;

    final admitted = reviewTake.map((e) => e.id).whereType<int>().toSet();
    final fresh = items.where((item) {
      final id = item.id;
      if (id == null || excludedIds.contains(id) || admitted.contains(id)) {
        return false;
      }
      if (item.learningState == LearningState.mastered ||
          item.learningState == LearningState.deferred) return false;
      return item.learningTimestamp == null;
    }).toList()
      ..shuffle(_random);

    return [
      ...reviewTake,
      ...fresh.take(size - reviewTake.length),
    ];
  }

  List<VocabularyItem> refillLearningWindow({
    required List<VocabularyItem> currentWindow,
    required List<VocabularyItem> allItems,
    required int windowSize,
    int? removedItemId,
  }) {
    final size = max(0, windowSize);
    if (size == 0) return [];

    // The Learning Window is a runtime working set and should stay full
    // whenever enough currently eligible VocabularyItems exist. Existing
    // admitted items remain admitted; only the vacancy is filled here.
    final survivors = currentWindow
        .where((item) => item.id != null && item.id != removedItemId)
        .toList();
    if (survivors.length >= size) return survivors.take(size).toList();

    final excluded = survivors.map((e) => e.id).whereType<int>().toSet();
    if (removedItemId != null) excluded.add(removedItemId);

    final remainingSlots = size - survivors.length;
    final additions = selectLearningWindow(
      items: allItems,
      windowSize: remainingSlots,
      excludedIds: excluded,
    );

    return [...survivors, ...additions];
  }

  VocabularyItem? selectNextFromWindow(List<VocabularyItem> window) {
    if (window.isEmpty) return null;
    final copy = List<VocabularyItem>.from(window)..shuffle(_random);
    return copy.first;
  }

  List<VocabularyItem> selectIntensiveCandidates({
    required List<VocabularyItem> items,
    required Set<int> setAsideIds,
    required List<int> presentationHistory,
    required int minimumInterval,
  }) {
    final eligible = items.where((item) {
      final id = item.id;
      if (id == null || setAsideIds.contains(id)) return false;
      return item.learningState != LearningState.mastered &&
          item.learningState != LearningState.deferred;
    }).toList();
    if (eligible.isEmpty) return [];
    var interval = max(0, minimumInterval);
    while (interval > 0) {
      final recent = presentationHistory
          .skip(max(0, presentationHistory.length - interval))
          .toSet();
      final candidates = eligible
          .where((item) => item.id != null && !recent.contains(item.id))
          .toList();
      if (candidates.isNotEmpty) return candidates;
      interval--;
    }
    return eligible;
  }

  VocabularyItem? chooseRandom(List<VocabularyItem> candidates) {
    if (candidates.isEmpty) return null;
    final copy = List<VocabularyItem>.from(candidates)..shuffle(_random);
    return copy.first;
  }

  Future<void> commitStandardResponse({
    required VocabularyItem item,
    required StandardLearningResponse response,
  }) async {
    if (item.id == null) return;
    final now = DateTime.now();
    LearningState state;
    DateTime? timestamp;
    switch (response) {
      case StandardLearningResponse.minutes10:
        state = LearningState.newItem;
        timestamp = now.add(const Duration(minutes: 10));
      case StandardLearningResponse.minutes30:
        state = LearningState.newItem;
        timestamp = now.add(const Duration(minutes: 30));
      case StandardLearningResponse.hours2:
        state = LearningState.newItem;
        timestamp = now.add(const Duration(hours: 2));
      case StandardLearningResponse.days2:
        state = LearningState.newItem;
        timestamp = now.add(const Duration(days: 2));
      case StandardLearningResponse.weeks2:
        state = LearningState.newItem;
        timestamp = now.add(const Duration(days: 14));
      case StandardLearningResponse.months2:
        state = LearningState.newItem;
        timestamp = _addMonths(now, 2);
      case StandardLearningResponse.mastered:
        state = LearningState.mastered;
      case StandardLearningResponse.deferred:
        state = LearningState.deferred;
    }
    await _vocabularyRepository.updateVocabularyItem(VocabularyItem(
      id: item.id,
      languageCombinationId: item.languageCombinationId,
      sourceExpression: item.sourceExpression,
      targetExpression: item.targetExpression,
      learningState: state,
      learningTimestamp: timestamp,
    ));
  }

  Future<void> commitIntensiveResponse({
    required VocabularyItem item,
    required IntensiveLearningResponse response,
  }) async {}

  DateTime _addMonths(DateTime value, int months) {
    final total = value.month - 1 + months;
    final year = value.year + total ~/ 12;
    final month = total % 12 + 1;
    final day = min(value.day, DateTime(year, month + 1, 0).day);
    return DateTime(year, month, day, value.hour, value.minute, value.second,
        value.millisecond, value.microsecond);
  }

}
