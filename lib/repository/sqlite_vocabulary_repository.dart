import 'package:sqflite/sqflite.dart';

import '../models/learning_state.dart';
import '../models/vocabulary_item.dart';
import 'database_manager.dart';
import 'vocabulary_repository.dart';

class SQLiteVocabularyRepository implements VocabularyRepository {
  final DatabaseManager _databaseManager = DatabaseManager.instance;

  @override
Future<int> insertVocabularyItem(VocabularyItem item) async {
  final db = await _databaseManager.database;

  return await db.insert(
    'VocabularyItem',
    _toMap(item),
  );
}

  @override
Future<VocabularyItem?> getVocabularyItemById(int id) async {
  final db = await _databaseManager.database;

  final results = await db.query(
    'VocabularyItem',
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
Future<void> updateVocabularyItem(VocabularyItem item) async {
  final db = await _databaseManager.database;

  await db.update(
    'VocabularyItem',
    _toMap(item),
    where: 'id = ?',
    whereArgs: [item.id],
  );
}

 @override
Future<void> deleteVocabularyItem(int id) async {
  final db = await _databaseManager.database;

  await db.delete(
    'VocabularyItem',
    where: 'id = ?',
    whereArgs: [id],
  );
}

Map<String, Object?> _toMap(VocabularyItem item) {
  return {
    'id': item.id,
    'sourceLanguage': item.sourceLanguage,
    'targetLanguage': item.targetLanguage,
    'sourceExpression': item.sourceExpression,
    'targetExpression': item.targetExpression,
    'learningState': item.learningState?.name,
    'reviewTimestamp': item.reviewTimestamp?.millisecondsSinceEpoch,
  };
}

VocabularyItem _fromMap(Map<String, Object?> map) {
  return VocabularyItem(
    id: map['id'] as int?,
    sourceLanguage: map['sourceLanguage'] as String,
    targetLanguage: map['targetLanguage'] as String,
    sourceExpression: map['sourceExpression'] as String,
    targetExpression: map['targetExpression'] as String,
    learningState: _learningStateFromString(
      map['learningState'] as String?,
    ),
    reviewTimestamp: map['reviewTimestamp'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            map['reviewTimestamp'] as int,
          ),
  );
}

LearningState? _learningStateFromString(String? value) {
  if (value == null) return null;

  return LearningState.values.firstWhere(
    (state) => state.name == value,
  );
}

}