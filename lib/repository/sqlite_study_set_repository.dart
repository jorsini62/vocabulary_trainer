import 'package:sqflite/sqflite.dart';

import '../domain/study_set.dart';
import 'database_manager.dart';
import 'study_set_repository.dart';

class SQLiteStudySetRepository implements StudySetRepository {
  final DatabaseManager _databaseManager = DatabaseManager.instance;

  @override
  Future<int> insertStudySet(StudySet studySet) async {
    final db = await _databaseManager.database;

    return await db.insert(
      'StudySet',
      _toMap(studySet),
    );
  }

  @override
  Future<StudySet?> getStudySetById(int id) async {
    final db = await _databaseManager.database;

    final results = await db.query(
      'StudySet',
      where: 'id = ?',
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
      where: 'id = ?',
      whereArgs: [studySet.id],
    );
  }

  @override
  Future<void> deleteStudySet(int id) async {
    final db = await _databaseManager.database;

    await db.delete(
      'StudySet',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> addVocabularyItemToStudySet(
    int vocabularyItemId,
    int studySetId,
  ) async {
    final db = await _databaseManager.database;

    await db.insert(
      'StudySetMembership',
      {
        'studySetId': studySetId,
        'vocabularyItemId': vocabularyItemId,
      },
    );
  }

  @override
  Future<void> removeVocabularyItemFromStudySet(
    int vocabularyItemId,
    int studySetId,
  ) async {
    final db = await _databaseManager.database;

    await db.delete(
      'StudySetMembership',
      where: 'studySetId = ? AND vocabularyItemId = ?',
      whereArgs: [
        studySetId,
        vocabularyItemId,
      ],
    );
  }

  Map<String, Object?> _toMap(StudySet studySet) {
    return {
  'id': studySet.id,
  'sourceLanguage': studySet.sourceLanguage,
  'targetLanguage': studySet.targetLanguage,
  'name': studySet.name,
  'learningWindowSize': studySet.learningWindowSize,
};
  }

  StudySet _fromMap(Map<String, Object?> map) {
    return StudySet(
  id: map['id'] as int?,
  sourceLanguage: map['sourceLanguage'] as String,
  targetLanguage: map['targetLanguage'] as String,
  name: map['name'] as String,
  learningWindowSize: map['learningWindowSize'] as int,
);
  }
}