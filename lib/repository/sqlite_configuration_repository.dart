import 'database_manager.dart';
import 'configuration_repository.dart';
import '../domain/configuration.dart';
import 'package:sqflite/sqflite.dart';

class SQLiteConfigurationRepository implements ConfigurationRepository {
  final DatabaseManager _databaseManager = DatabaseManager.instance;

  @override
  Future<Configuration?> getConfiguration() async {
    final db = await _databaseManager.database;

    final rows = await db.query('Configuration', limit: 1);

    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;

    return Configuration(
      id: row['ConfigurationID'] as int,
      currentLanguagePairId: row['CurrentLanguagePairID'] as int?,
      currentStudySetId: row['CurrentStudySetID'] as int?,
    );
  }

  @override
  Future<void> saveConfiguration(Configuration configuration) async {
    final db = await _databaseManager.database;

    await db.insert('Configuration', {
      'ConfigurationID': configuration.id,
      'CurrentLanguagePairID': configuration.currentLanguagePairId,
      'CurrentStudySetID': configuration.currentStudySetId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
