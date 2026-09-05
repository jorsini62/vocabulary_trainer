import 'package:sqflite/sqflite.dart';

import '../domain/study_set.dart';
import 'database_manager.dart';
import 'study_set_repository.dart';

class SQLiteStudySetRepository implements StudySetRepository {
  final DatabaseManager _databaseManager = DatabaseManager.instance;

  @override
  Future<int> insertStudySet(StudySet studySet) async {
    final db = await _databaseManager.database;

    return await db.insert('StudySet', _toMap(studySet));
  }

  @override
  Future<StudySet?> getStudySetById(int id) async {
    final db = await _databaseManager.database;

    final results = await db.query(
      'StudySet',
      where: 'StudySetID = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) {
      return null;
    }

    return _fromMap(results.first);
  }

  @override
  Future<void> updateStudySet(StudySet studySet) async {
    final db = await _databaseManager.database;

    await db.update(
      'StudySet',
      _toMap(studySet),
      where: 'StudySetID = ?',
      whereArgs: [studySet.id],
    );
  }

  @override
  Future<void> deleteStudySet(int id) async {
    final db = await _databaseManager.database;

    // Configuration.CurrentStudySetID has a foreign-key reference to StudySet.
    // Clear the current context first so the selected Study Set can actually
    // be deleted. The caller will then select and persist the default Study Set
    // (Repository) as the new current context.
    await db.transaction((txn) async {
      await txn.update(
        'Configuration',
        {'CurrentStudySetID': null},
        where: 'CurrentStudySetID = ?',
        whereArgs: [id],
      );

      await txn.delete(
        'StudySetMembership',
        where: 'StudySetID = ?',
        whereArgs: [id],
      );

      final deletedCount = await txn.delete(
        'StudySet',
        where: 'StudySetID = ?',
        whereArgs: [id],
      );

      if (deletedCount != 1) {
        throw StateError('Study Set could not be deleted.');
      }
    });
  }

  @override
  Future<void> addVocabularyItemToStudySet(
    int vocabularyItemId,
    int studySetId,
  ) async {
    final db = await _databaseManager.database;

    await db.insert('StudySetMembership', {
      'StudySetID': studySetId,
      'VocabularyItemID': vocabularyItemId,
    });
  }

  @override
  Future<void> removeVocabularyItemFromStudySet(
    int vocabularyItemId,
    int studySetId,
  ) async {
    final db = await _databaseManager.database;

    await db.delete(
      'StudySetMembership',
      where: 'StudySetID = ? AND VocabularyItemID = ?',
      whereArgs: [studySetId, vocabularyItemId],
    );
  }

  @override
  Future<List<StudySet>> getStudySetsByLanguageCombinationId(
    int languageCombinationId,
  ) async {
    final db = await _databaseManager.database;

    final results = await db.query(
      'StudySet',
      where: 'LanguageCombinationID = ?',
      whereArgs: [languageCombinationId],
      orderBy: 'StudySetName COLLATE NOCASE',
    );

    return results.map(_fromMap).toList();
  }

  @override
  Future<List<StudySet>> getAllStudySets() async {
    final db = await _databaseManager.database;

    final results = await db.query(
      'StudySet',
      orderBy: 'StudySetName COLLATE NOCASE',
    );

    return results.map(_fromMap).toList();
  }


  @override
  Future<StudySet?> getDefaultStudySet(int languageCombinationId) async {
    final db = await _databaseManager.database;

    final results = await db.query(
      'StudySet',
      where: 'LanguageCombinationID = ? AND IsDefaultStudySet = 1',
      whereArgs: [languageCombinationId],
      limit: 1,
    );

    if (results.isEmpty) {
      return null;
    }

    return _fromMap(results.first);
  }


  @override
  Future<List<int>> getVocabularyItemIdsForStudySet(int studySetId) async {
    final db = await _databaseManager.database;

    final rows = await db.query(
      'StudySetMembership',
      columns: ['VocabularyItemID'],
      where: 'StudySetID = ?',
      whereArgs: [studySetId],
      orderBy: 'VocabularyItemID',
    );

    return rows
        .map((row) => row['VocabularyItemID'])
        .whereType<int>()
        .toList();
  }

  @override
  Future<Set<int>> getStudySetIdsForVocabularyItem(int vocabularyItemId) async {
    final db = await _databaseManager.database;

    final rows = await db.query(
      'StudySetMembership',
      columns: ['StudySetID'],
      where: 'VocabularyItemID = ?',
      whereArgs: [vocabularyItemId],
      orderBy: 'StudySetID',
    );

    return rows
        .map((row) => row['StudySetID'])
        .whereType<int>()
        .toSet();
  }

  @override
  Future<Map<String, int>> getStudySetStatistics(int studySetId) async {
    final db = await _databaseManager.database;

    final rows = await db.rawQuery(
      "SELECT v.LearningState, v.LearningTimestamp "
      "FROM StudySetMembership m "
      "INNER JOIN VocabularyItem v "
      "ON v.VocabularyItemID = m.VocabularyItemID "
      "WHERE m.StudySetID = ?",
      [studySetId],
    );

    int vocabularyItems = rows.length;
    int activeItems = 0;
    int waitingItems = 0;
    int deferredItems = 0;
    int masteredItems = 0;

    final now = DateTime.now().millisecondsSinceEpoch;

    for (final row in rows) {
      final state = row['LearningState']?.toString();
      final timestamp = row['LearningTimestamp'] as int?;

      if (state == 'deferred') {
        deferredItems++;
        continue;
      }

      if (state == 'mastered') {
        masteredItems++;
        continue;
      }

      if (timestamp != null && timestamp > now) {
        waitingItems++;
      } else {
        activeItems++;
      }
    }

    return {
      'vocabularyItems': vocabularyItems,
      'activeItems': activeItems,
      'waitingItems': waitingItems,
      'deferredItems': deferredItems,
      'masteredItems': masteredItems,
    };
  }

  Map<String, Object?> _toMap(StudySet studySet) {
    return {
      'StudySetID': studySet.id,
      'LanguageCombinationID': studySet.languageCombinationId,
      'StudySetName': studySet.name,
      'StandardLearningWindowSize': studySet.standardLearningWindowSize,
      'IntenseLearningWindowSize': studySet.intenseLearningWindowSize,
      'MinimumInterval': studySet.minimumInterval,
      'IsDefaultStudySet': studySet.isDefaultStudySet ? 1 : 0,
    };
  }

  StudySet _fromMap(Map<String, Object?> map) {
  print(map);

  return StudySet(
    id: map['StudySetID'] as int?,
    languageCombinationId: map['LanguageCombinationID'] as int,
    name: map['StudySetName'] as String,
    standardLearningWindowSize: map['StandardLearningWindowSize'] as int,
    intenseLearningWindowSize: map['IntenseLearningWindowSize'] as int,
    minimumInterval: map['MinimumInterval'] as int,
    isDefaultStudySet: (map['IsDefaultStudySet'] as int) != 0,
  );
}
}
