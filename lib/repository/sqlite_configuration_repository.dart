import 'package:sqflite/sqflite.dart';

import '../domain/configuration.dart';
import 'configuration_repository.dart';
import 'database_manager.dart';

class SQLiteConfigurationRepository implements ConfigurationRepository {
  final DatabaseManager _databaseManager = DatabaseManager.instance;

  @override
  Future<Configuration?> getConfiguration() async {
    final db = await _databaseManager.database;

    final rows = await db.query(
      'Configuration',
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;

    return Configuration(
      id: row['ConfigurationID'] as int,
      currentLanguagePairId:
          (row['CurrentLanguageCombinationID'] ??
                  row['CurrentLanguagePairID'])
              as int?,
      currentStudySetId:
          row['CurrentStudySetID'] as int?,
      backupLocation:
          row['BackupLocation'] as String?,
      backupBookmark:
          row['BackupBookmark'] as String?,
    );
  }

  @override
  Future<void> saveConfiguration(
    Configuration configuration,
  ) async {
    final db = await _databaseManager.database;

    // Preserve backup settings when callers only update language/study context.
    final existingRows = await db.query(
      'Configuration',
      columns: ['BackupLocation', 'BackupBookmark'],
      where: 'ConfigurationID = ?',
      whereArgs: [configuration.id],
      limit: 1,
    );

    final existing = existingRows.isEmpty ? null : existingRows.first;
    final backupLocation = configuration.backupLocation ??
        existing?['BackupLocation'] as String?;
    final backupBookmark = configuration.backupBookmark ??
        existing?['BackupBookmark'] as String?;

    await db.insert(
      'Configuration',
      {
        'ConfigurationID': configuration.id,
        'CurrentLanguageCombinationID':
            configuration.currentLanguagePairId,
        'CurrentStudySetID':
            configuration.currentStudySetId,
        'BackupLocation': backupLocation,
        'BackupBookmark': backupBookmark,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Replaces backup settings, including clearing them when null.
  Future<void> saveBackupSettings({
    required int configurationId,
    required int? currentLanguagePairId,
    required int? currentStudySetId,
    required String? backupLocation,
    required String? backupBookmark,
  }) async {
    final db = await _databaseManager.database;

    await db.insert(
      'Configuration',
      {
        'ConfigurationID': configurationId,
        'CurrentLanguageCombinationID': currentLanguagePairId,
        'CurrentStudySetID': currentStudySetId,
        'BackupLocation': backupLocation,
        'BackupBookmark': backupBookmark,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
