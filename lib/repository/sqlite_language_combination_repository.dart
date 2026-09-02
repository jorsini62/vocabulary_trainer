import '../domain/language_combination.dart';
import 'database_manager.dart';
import 'language_combination_repository.dart';

class SQLiteLanguageCombinationRepository
    implements LanguageCombinationRepository {
  final DatabaseManager _databaseManager = DatabaseManager.instance;

  @override
  Future<int> insert(LanguageCombination languageCombination) async {
    final db = await _databaseManager.database;

    return await db.insert('LanguageCombination', {
      'SourceLanguage': languageCombination.sourceLanguage.trim(),
      'TargetLanguage': languageCombination.targetLanguage.trim(),
    });
  }

  @override
  Future<LanguageCombination?> getById(int id) async {
    final db = await _databaseManager.database;

    final rows = await db.query(
      'LanguageCombination',
      where: 'LanguageCombinationID = ?',
      whereArgs: [id],
    );

    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;

    return LanguageCombination(
      id: row['LanguageCombinationID'] as int,
      sourceLanguage: row['SourceLanguage'] as String,
      targetLanguage: row['TargetLanguage'] as String,
    );
  }

  @override
  Future<List<LanguageCombination>> getAll() async {
    final db = await _databaseManager.database;

    final rows = await db.query(
      'LanguageCombination',
      orderBy: 'SourceLanguage, TargetLanguage',
    );

    return rows
        .map(
          (row) => LanguageCombination(
            id: row['LanguageCombinationID'] as int,
            sourceLanguage: row['SourceLanguage'] as String,
            targetLanguage: row['TargetLanguage'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<LanguageCombination?> getFirst() async {
    final db = await _databaseManager.database;

    final rows = await db.query(
      'LanguageCombination',
      orderBy: 'LanguageCombinationID',
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;

    return LanguageCombination(
      id: row['LanguageCombinationID'] as int,
      sourceLanguage: row['SourceLanguage'] as String,
      targetLanguage: row['TargetLanguage'] as String,
    );
  }

  @override
  Future<void> update(LanguageCombination languageCombination) async {
    final db = await _databaseManager.database;

    await db.update(
      'LanguageCombination',
      {
        'SourceLanguage': languageCombination.sourceLanguage.trim(),
        'TargetLanguage': languageCombination.targetLanguage.trim(),
      },
      where: 'LanguageCombinationID = ?',
      whereArgs: [languageCombination.id],
    );
  }

  @override
  Future<void> delete(int id) async {
    final db = await _databaseManager.database;

    await db.delete(
      'LanguageCombination',
      where: 'LanguageCombinationID = ?',
      whereArgs: [id],
    );
  }
}
