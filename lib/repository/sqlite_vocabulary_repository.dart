import 'package:sqflite/sqflite.dart';

import '../domain/learning_state.dart';
import '../domain/vocabulary_item.dart';
import 'database_manager.dart';
import 'vocabulary_repository.dart';

class SQLiteVocabularyRepository implements VocabularyRepository {
  final DatabaseManager _databaseManager = DatabaseManager.instance;

  @override
  Future<int> insertVocabularyItem(VocabularyItem item) async {
    final db = await _databaseManager.database;

    return await db.insert('VocabularyItem', _toMap(item));
  }

  @override
  Future<VocabularyItem?> getVocabularyItemById(int id) async {
    final db = await _databaseManager.database;

    final results = await db.query(
      'VocabularyItem',
      where: 'VocabularyItemID = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) {
      return null;
    }

    return _fromMap(results.first);
  }

  @override
  Future<List<VocabularyItem>> getVocabularyItemsByLanguageCombinationId(
    int languageCombinationId,
  ) async {
    final db = await _databaseManager.database;

    final results = await db.query(
      'VocabularyItem',
      where: 'LanguageCombinationID = ?',
      whereArgs: [languageCombinationId],
      orderBy: 'SourceExpression COLLATE NOCASE',
    );

    return results.map(_fromMap).toList();
  }

  @override
  Future<void> updateVocabularyItem(VocabularyItem item) async {
    final db = await _databaseManager.database;

    await db.update(
      'VocabularyItem',
      _toMap(item),
      where: 'VocabularyItemID = ?',
      whereArgs: [item.id],
    );
  }

  @override
  Future<void> updateVocabularyExpressions(
    int vocabularyItemId,
    String sourceExpression,
    String targetExpression,
  ) async {
    final db = await _databaseManager.database;

    await db.update(
      'VocabularyItem',
      {
        'SourceExpression': sourceExpression,
        'NormalizedSourceExpression': sourceExpression.trim().toLowerCase(),
        'TargetExpression': targetExpression,
      },
      where: 'VocabularyItemID = ?',
      whereArgs: [vocabularyItemId],
    );
  }

  @override
  Future<void> deleteVocabularyItem(int id) async {
    final db = await _databaseManager.database;

    await db.delete(
      'VocabularyItem',
      where: 'VocabularyItemID = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<bool> sourceExpressionExists(
    int languageCombinationId,
    String sourceExpression,
  ) async {
    final db = await _databaseManager.database;

    final results = await db.query(
      'VocabularyItem',
      columns: ['VocabularyItemID'],
      where:
          'LanguageCombinationID = ? '
          'AND NormalizedSourceExpression = ?',
      whereArgs: [languageCombinationId, sourceExpression.trim().toLowerCase()],
      limit: 1,
    );

    return results.isNotEmpty;
  }

  Future<int?> getVocabularyItemIdBySourceExpression(
    int languageCombinationId,
    String sourceExpression,
  ) async {
    final db = await _databaseManager.database;

    final results = await db.query(
      'VocabularyItem',
      columns: ['VocabularyItemID'],
      where:
          'LanguageCombinationID = ? '
          'AND NormalizedSourceExpression = ?',
      whereArgs: [languageCombinationId, sourceExpression.trim().toLowerCase()],
      limit: 1,
    );

    if (results.isEmpty) {
      return null;
    }

    return results.first['VocabularyItemID'] as int;
  }

  Map<String, Object?> _toMap(VocabularyItem item) {
    return {
      'VocabularyItemID': item.id,
      'LanguageCombinationID': item.languageCombinationId,
      'SourceExpression': item.sourceExpression,
      'TargetExpression': item.targetExpression,
      'NormalizedSourceExpression': item.sourceExpression.trim().toLowerCase(),
      'LearningState': item.learningState.name,
      'LearningTimestamp': item.learningTimestamp?.millisecondsSinceEpoch,
    };
  }

  VocabularyItem _fromMap(Map<String, Object?> map) {
    return VocabularyItem(
      id: map['VocabularyItemID'] as int?,
      languageCombinationId: map['LanguageCombinationID'] as int,
      sourceExpression: map['SourceExpression'] as String,
      targetExpression: map['TargetExpression'] as String,
      learningState: LearningState.values.byName(
        map['LearningState'] as String,
      ),
      learningTimestamp: map['LearningTimestamp'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              map['LearningTimestamp'] as int,
            ),
    );
  }
}
