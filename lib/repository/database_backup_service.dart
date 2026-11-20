import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:macos_security_scoped_bookmarks/macos_security_scoped_bookmarks.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/configuration.dart';
import 'database_manager.dart';
import 'ios_backup_directory.dart';
import 'sqlite_configuration_repository.dart';

class DatabaseBackupException implements Exception {
  final String message;

  const DatabaseBackupException(this.message);

  @override
  String toString() => message;
}

class DatabaseBackupInfo {
  final int version;
  final int vocabularyItemCount;
  final int studySetCount;
  final int languageCombinationCount;
  final int membershipCount;

  const DatabaseBackupInfo({
    required this.version,
    required this.vocabularyItemCount,
    required this.studySetCount,
    required this.languageCombinationCount,
    required this.membershipCount,
  });
}

class AutomaticBackupResult {
  final String destinationPath;
  final bool created;

  const AutomaticBackupResult({
    required this.destinationPath,
    required this.created,
  });
}

class DatabaseBackupService {
  static const int currentDatabaseVersion = 9;
  static const String databaseFileName = 'vocabulary_trainer.db';
  static const String backupFilePrefix = 'vocabulary_trainer_backup_';
  static const String backupFileSuffix = '.db';
  static const int maxRollingBackups = 2;
  static const Duration backupMaxAge = Duration(hours: 24);

  final DatabaseManager _databaseManager = DatabaseManager.instance;
  final SQLiteConfigurationRepository _configurationRepository =
      SQLiteConfigurationRepository();

  Future<String> defaultBackupDirectoryPath() async {
    final documents = await getApplicationDocumentsDirectory();
    return p.join(documents.path, 'Backups');
  }

  Future<void> exportDatabase({
    required String destinationPath,
  }) async {
    final db = await _databaseManager.database;
    final sourcePath = db.path;

    await db.rawQuery('PRAGMA wal_checkpoint(FULL);');

    await _databaseManager.close();

    try {
      final sourceFile = File(sourcePath);

      if (!await sourceFile.exists()) {
        throw const DatabaseBackupException(
          'The application database could not be found.',
        );
      }

      final destinationFile = File(destinationPath);
      await destinationFile.parent.create(recursive: true);

      if (await destinationFile.exists()) {
        await destinationFile.delete();
      }

      await sourceFile.copy(destinationPath);
    } finally {
      await _databaseManager.database;
    }
  }

  Future<DatabaseBackupInfo> validateDatabase(
    String filePath,
  ) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw const DatabaseBackupException(
        'The selected database file does not exist.',
      );
    }

    if (await file.length() == 0) {
      throw const DatabaseBackupException(
        'The selected database file is empty.',
      );
    }

    Database? db;

    try {
      db = await openDatabase(
        filePath,
        readOnly: true,
        singleInstance: false,
      );

      final version = await db.getVersion();

      if (version > currentDatabaseVersion) {
        throw DatabaseBackupException(
          'The selected database uses schema version $version, '
          'but this application supports version '
          '$currentDatabaseVersion or earlier.',
        );
      }

      final integrityResult = await db.rawQuery(
        'PRAGMA integrity_check;',
      );

      if (integrityResult.isEmpty ||
          integrityResult.first.values.first != 'ok') {
        throw const DatabaseBackupException(
          'The selected database failed SQLite integrity checking.',
        );
      }

      final tables = await db.rawQuery('''
        SELECT name
        FROM sqlite_master
        WHERE type = 'table'
      ''');

      final tableNames = tables
          .map((row) => row['name'] as String?)
          .whereType<String>()
          .toSet();

      const requiredTables = {
        'LanguageCombination',
        'VocabularyItem',
        'StudySet',
        'StudySetMembership',
        'Configuration',
      };

      final missingTables = requiredTables.difference(tableNames);

      if (missingTables.isNotEmpty) {
        throw DatabaseBackupException(
          'The selected file is not a valid Vocabulary Trainer database. '
          'Missing table(s): ${missingTables.join(', ')}.',
        );
      }

      final vocabularyItemCount =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM VocabularyItem',
            ),
          ) ??
          0;

      final studySetCount =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM StudySet',
            ),
          ) ??
          0;

      final languageCombinationCount =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM LanguageCombination',
            ),
          ) ??
          0;

      final membershipCount =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM StudySetMembership',
            ),
          ) ??
          0;

      return DatabaseBackupInfo(
        version: version,
        vocabularyItemCount: vocabularyItemCount,
        studySetCount: studySetCount,
        languageCombinationCount: languageCombinationCount,
        membershipCount: membershipCount,
      );
    } on DatabaseBackupException {
      rethrow;
    } catch (e) {
      throw DatabaseBackupException(
        'The selected file could not be opened as a SQLite database: $e',
      );
    } finally {
      await db?.close();
    }
  }

  Future<DatabaseBackupInfo> restoreDatabase({
    required String sourcePath,
  }) async {
    final info = await validateDatabase(sourcePath);

    final configuration = await _configurationRepository.getConfiguration();
    final preservedBackupLocation = configuration?.backupLocation;
    final preservedBackupBookmark = configuration?.backupBookmark;

    final currentDb = await _databaseManager.database;
    final databasePath = currentDb.path;

    await currentDb.rawQuery('PRAGMA wal_checkpoint(FULL);');
    await _databaseManager.close();

    final databaseFile = File(databasePath);

    final safetyBackupPath = p.join(
      p.dirname(databasePath),
      'vocabulary_trainer_pre_restore.db',
    );

    final temporaryPath = p.join(
      p.dirname(databasePath),
      'vocabulary_trainer_restore_temp.db',
    );

    try {
      if (await File(temporaryPath).exists()) {
        await File(temporaryPath).delete();
      }

      await File(sourcePath).copy(temporaryPath);

      if (await File(safetyBackupPath).exists()) {
        await File(safetyBackupPath).delete();
      }

      if (await databaseFile.exists()) {
        await databaseFile.copy(safetyBackupPath);
        await databaseFile.delete();
      }

      await File(temporaryPath).rename(databasePath);

      await _databaseManager.database;

      // Keep this device's backup folder settings after a full restore.
      final restored = await _configurationRepository.getConfiguration();
      await _configurationRepository.saveBackupSettings(
        configurationId: restored?.id ?? 1,
        currentLanguagePairId: restored?.currentLanguagePairId,
        currentStudySetId: restored?.currentStudySetId,
        backupLocation: preservedBackupLocation,
        backupBookmark: preservedBackupBookmark,
      );

      return info;
    } catch (e) {
      if (await File(temporaryPath).exists()) {
        await File(temporaryPath).delete();
      }

      if (!await databaseFile.exists() &&
          await File(safetyBackupPath).exists()) {
        await File(safetyBackupPath).copy(databasePath);
      }

      await _databaseManager.database;

      throw DatabaseBackupException(
        'Database restoration failed. The previous database was preserved. '
        'Details: $e',
      );
    }
  }

  /// Creates a rolling backup when none exist or the newest is older than 24h.
  Future<AutomaticBackupResult?> ensureAutomaticBackupIfNeeded() async {
    try {
      return await _withBackupDirectoryAccess((directoryPath) async {
        final newest = await _newestAutomaticBackupIn(directoryPath);
        if (newest != null) {
          final age = DateTime.now().difference(newest.modified);
          if (age < backupMaxAge) {
            return AutomaticBackupResult(
              destinationPath: newest.path,
              created: false,
            );
          }
        }

        return _createAutomaticBackupIn(directoryPath);
      });
    } catch (e) {
      debugPrint('Automatic backup check failed: $e');
      return null;
    }
  }

  /// Creates a new rolling backup and keeps at most [maxRollingBackups] files.
  Future<AutomaticBackupResult> createAutomaticBackup() async {
    return _withBackupDirectoryAccess(_createAutomaticBackupIn);
  }

  Future<AutomaticBackupResult> _createAutomaticBackupIn(
    String directoryPath,
  ) async {
    final fileName =
        '$backupFilePrefix${_timestampLabel()}$backupFileSuffix';
    final destinationPath = p.join(directoryPath, fileName);

    await exportDatabase(destinationPath: destinationPath);
    await _pruneOldAutomaticBackups(directoryPath);

    return AutomaticBackupResult(
      destinationPath: destinationPath,
      created: true,
    );
  }

  Future<Directory> ensureDefaultBackupDirectory() async {
    final path = await defaultBackupDirectoryPath();
    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<T> _withBackupDirectoryAccess<T>(
    Future<T> Function(String directoryPath) action,
  ) async {
    final configuration = await _configurationRepository.getConfiguration();
    final configuredPath = configuration?.backupLocation?.trim();
    final bookmarkValue = configuration?.backupBookmark;

    if (configuredPath != null &&
        configuredPath.isNotEmpty &&
        bookmarkValue != null &&
        bookmarkValue.isNotEmpty) {
      if (Platform.isMacOS && !IosBackupDirectory.isIosBookmark(bookmarkValue)) {
        final bookmark = MacOSSecurityScopedBookmark.decode(bookmarkValue);

        return withBookmarkAccess(bookmark, (resource) async {
          if (resource.isStale) {
            final refreshed = await resource.refreshBookmark();
            await _persistRefreshedMacBookmark(configuration!, refreshed);
          }

          final directoryPath = resource.entity.path;
          final directory = Directory(directoryPath);
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }

          return action(directoryPath);
        });
      }

      if (Platform.isIOS && IosBackupDirectory.isIosBookmark(bookmarkValue)) {
        return IosBackupDirectory.withBookmarkAccess(
          storedBookmark: bookmarkValue,
          action: (directoryPath) async {
            final directory = Directory(directoryPath);
            if (!await directory.exists()) {
              await directory.create(recursive: true);
            }
            return action(directoryPath);
          },
        );
      }
    }

    final directory = configuredPath != null && configuredPath.isNotEmpty
        ? Directory(configuredPath)
        : await ensureDefaultBackupDirectory();

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return action(directory.path);
  }

  Future<void> _persistRefreshedMacBookmark(
    Configuration configuration,
    MacOSSecurityScopedBookmark bookmark,
  ) async {
    await _configurationRepository.saveBackupSettings(
      configurationId: configuration.id,
      currentLanguagePairId: configuration.currentLanguagePairId,
      currentStudySetId: configuration.currentStudySetId,
      backupLocation: configuration.backupLocation,
      backupBookmark: bookmark.encode(),
    );
  }

  Future<({String path, DateTime modified})?> _newestAutomaticBackupIn(
    String directoryPath,
  ) async {
    final files = await _listAutomaticBackups(directoryPath);
    if (files.isEmpty) return null;

    files.sort((a, b) => b.modified.compareTo(a.modified));
    return files.first;
  }

  Future<List<({String path, DateTime modified})>> _listAutomaticBackups(
    String directoryPath,
  ) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      return [];
    }

    final results = <({String path, DateTime modified})>[];

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;

      final name = p.basename(entity.path);
      if (!name.startsWith(backupFilePrefix) ||
          !name.endsWith(backupFileSuffix)) {
        continue;
      }

      results.add((
        path: entity.path,
        modified: await entity.lastModified(),
      ));
    }

    return results;
  }

  Future<void> _pruneOldAutomaticBackups(String directoryPath) async {
    final files = await _listAutomaticBackups(directoryPath);
    if (files.length <= maxRollingBackups) return;

    files.sort((a, b) => b.modified.compareTo(a.modified));

    for (final outdated in files.skip(maxRollingBackups)) {
      try {
        await File(outdated.path).delete();
      } catch (_) {
        // Best-effort cleanup; a leftover file is not fatal.
      }
    }
  }

  String _timestampLabel() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');

    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}
