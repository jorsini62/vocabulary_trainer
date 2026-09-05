import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../domain/learning_state.dart';
import '../repository/database_manager.dart';
import 'transfer_json_codec.dart';
import 'transfer_models.dart';

class TransferValidationException implements Exception {
  final String message;

  const TransferValidationException(this.message);

  @override
  String toString() => 'TransferValidationException: $message';
}

typedef TransferContentResolver = Future<String> Function(
  TransferContentConflict conflict,
);
typedef TransferHistoryOverwriteWarning = Future<bool> Function();

class TransferService {
  final DatabaseManager _databaseManager = DatabaseManager.instance;
  final TransferJsonCodec _codec = TransferJsonCodec();

  Future<void> exportStudySet({
    required int studySetId,
    required String filePath,
  }) async {
    final db = await _databaseManager.database;

    final studySetRows = await db.query(
      'StudySet',
      where: 'StudySetID = ?',
      whereArgs: [studySetId],
      limit: 1,
    );
    if (studySetRows.isEmpty) {
      throw const TransferValidationException('The selected Study Set does not exist.');
    }
    final studySet = studySetRows.first;
    final languageCombinationId = studySet['LanguageCombinationID'] as int;

    final languageRows = await db.query(
      'LanguageCombination',
      where: 'LanguageCombinationID = ?',
      whereArgs: [languageCombinationId],
      limit: 1,
    );
    if (languageRows.isEmpty) {
      throw const TransferValidationException('The Study Set has no valid Language Pair.');
    }
    final language = languageRows.first;

    final membershipRows = await db.query(
      'StudySetMembership',
      columns: ['VocabularyItemID'],
      where: 'StudySetID = ?',
      whereArgs: [studySetId],
    );
    final ids = membershipRows
        .map((row) => row['VocabularyItemID'] as int)
        .toList(growable: false);

    final vocabularyItems = <TransferVocabularyItemData>[];
    for (final id in ids) {
      final rows = await db.query(
        'VocabularyItem',
        where: 'VocabularyItemID = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        continue;
      }
      final item = rows.first;
      vocabularyItems.add(
        _vocabularyItemFromRow(item, languageCombinationId, language),
      );
    }

    final package = TransferStudySetPackage(
      formatVersion: TransferJsonCodec.currentFormatVersion,
      transferType: TransferJsonCodec.studySetTransferType,
      exportedAt: DateTime.now().toUtc(),
      languagePair: TransferLanguagePairData(
        sourceLanguage: language['SourceLanguage'] as String,
        targetLanguage: language['TargetLanguage'] as String,
      ),
      sourceStudySetName: studySet['StudySetName'] as String,
      vocabularyItems: vocabularyItems,
    );

    await File(filePath).writeAsString(
      _codec.encodeStudySet(package),
      flush: true,
    );
  }

  Future<void> exportEverything({required String filePath}) async {
    final db = await _databaseManager.database;

    // A Database Transfer represents the complete environment. Include all
    // Language Pairs and all Study Sets; there is no longer a special
    // bootstrap Language Pair/Study Set to exclude.
    final languageRows = await db.query(
      'LanguageCombination',
      orderBy: 'LanguageCombinationID',
    );
    final studySetRows = await db.query(
      'StudySet',
      orderBy: 'StudySetID',
    );
    final vocabularyRows = await db.query(
      'VocabularyItem',
      orderBy: 'VocabularyItemID',
    );
    final membershipRows = await db.query('StudySetMembership');

    final languagesById = <int, TransferLanguagePairData>{};
    for (final row in languageRows) {
      final id = row['LanguageCombinationID'] as int;
      languagesById[id] = TransferLanguagePairData(
        sourceLanguage: row['SourceLanguage'] as String,
        targetLanguage: row['TargetLanguage'] as String,
      );
    }

    final studySetById = <int, Map<String, Object?>>{};
    final studySets = <TransferStudySetData>[];
    for (final row in studySetRows) {
      final id = row['StudySetID'] as int;
      studySetById[id] = row;
      final pair = languagesById[row['LanguageCombinationID'] as int];
      if (pair == null) {
        throw const TransferValidationException(
          'A Study Set refers to a missing Language Pair.',
        );
      }
      studySets.add(
        TransferStudySetData(
          languagePair: pair,
          name: row['StudySetName'] as String,
          isDefaultStudySet: (row['IsDefaultStudySet'] as int) != 0,
          standardLearningWindowSize:
              row['StandardLearningWindowSize'] as int,
          intenseLearningWindowSize:
              row['IntenseLearningWindowSize'] as int,
          minimumInterval: row['MinimumInterval'] as int,
        ),
      );
    }

    final vocabularyItems = <TransferVocabularyItemData>[];
    final pairById = languagesById;
    for (final row in vocabularyRows) {
      final languageCombinationId = row['LanguageCombinationID'] as int;
      final pair = pairById[languageCombinationId];
      if (pair == null) {
        throw const TransferValidationException(
          'A Vocabulary Item refers to a missing Language Pair.',
        );
      }
      vocabularyItems.add(
        _vocabularyItemFromRow(row, languageCombinationId, {
          'SourceLanguage': pair.sourceLanguage,
          'TargetLanguage': pair.targetLanguage,
        }),
      );
    }

    final memberships = <TransferMembershipData>[];
    final vocabularyById = <int, Map<String, Object?>>{
      for (final row in vocabularyRows)
        row['VocabularyItemID'] as int: row,
    };
    for (final row in membershipRows) {
      final studySet = studySetById[row['StudySetID'] as int];
      final vocabulary = vocabularyById[row['VocabularyItemID'] as int];
      if (studySet == null || vocabulary == null) {
        throw const TransferValidationException(
          'The database contains an invalid Study Set membership.',
        );
      }
      final pair = languagesById[studySet['LanguageCombinationID'] as int];
      if (pair == null) {
        throw const TransferValidationException(
          'A Study Set membership refers to a missing Language Pair.',
        );
      }
      memberships.add(
        TransferMembershipData(
          languagePair: pair,
          studySetName: studySet['StudySetName'] as String,
          normalizedSourceExpression:
              vocabulary['NormalizedSourceExpression'] as String,
        ),
      );
    }

    final package = TransferEverythingPackage(
      formatVersion: TransferJsonCodec.currentFormatVersion,
      transferType: TransferJsonCodec.everythingTransferType,
      exportedAt: DateTime.now().toUtc(),
      languagePairs: languagesById.values.toList(growable: false),
      studySets: studySets,
      vocabularyItems: vocabularyItems,
      memberships: memberships,
    );

    await File(filePath).writeAsString(
      _codec.encodeEverything(package),
      flush: true,
    );
  }

  Future<TransferImportPlan> prepareStudySetImport({
    required String filePath,
    required int targetStudySetId,
  }) async {
    final package = _codec.decodeStudySet(await File(filePath).readAsString());
    final db = await _databaseManager.database;
    final targetStudySet = await _getStudySet(db, targetStudySetId);
    final targetPair = await _getLanguagePair(
      db,
      targetStudySet['LanguageCombinationID'] as int,
    );

    _ensureSameLanguagePair(package.languagePair, targetPair);

    final newItems = <TransferVocabularyItemData>[];
    final exactMatches = <TransferVocabularyItemData>[];
    final conflicts = <TransferContentConflict>[];
    var historyOverwrite = false;

    for (final imported in package.vocabularyItems) {
      final existing = await _findVocabularyItem(
        db,
        languageCombinationId:
            targetStudySet['LanguageCombinationID'] as int,
        normalizedSourceExpression: imported.normalizedSourceExpression,
      );

      if (existing == null) {
        newItems.add(imported);
        continue;
      }

      if ((existing['TargetExpression'] as String) != imported.targetExpression) {
        conflicts.add(
          TransferContentConflict(
            importedItem: imported,
            existingTargetExpression: existing['TargetExpression'] as String,
          ),
        );
      } else {
        exactMatches.add(imported);
      }

      if (_learningHistoryDiffers(existing, imported)) {
        historyOverwrite = true;
      }
    }

    return TransferImportPlan(
      newItems: newItems,
      exactMatches: exactMatches,
      contentConflicts: conflicts,
      learningHistoryWillBeOverwritten: historyOverwrite,
    );
  }

  Future<void> applyStudySetImport({
    required String filePath,
    required int targetStudySetId,
    Map<String, String> resolvedTargetExpressions = const {},
    bool allowLearningHistoryOverwrite = false,
  }) async {
    final package = _codec.decodeStudySet(await File(filePath).readAsString());
    final db = await _databaseManager.database;
    final targetStudySet = await _getStudySet(db, targetStudySetId);
    final targetLanguageCombinationId =
        targetStudySet['LanguageCombinationID'] as int;
    final targetPair = await _getLanguagePair(db, targetLanguageCombinationId);

    _ensureSameLanguagePair(package.languagePair, targetPair);

    await db.transaction((txn) async {
      for (final imported in package.vocabularyItems) {
        var existing = await _findVocabularyItem(
          txn,
          languageCombinationId: targetLanguageCombinationId,
          normalizedSourceExpression: imported.normalizedSourceExpression,
        );

        if (existing == null) {
          final id = await txn.insert('VocabularyItem', {
            'LanguageCombinationID': targetLanguageCombinationId,
            'SourceExpression': imported.sourceExpression,
            'NormalizedSourceExpression': imported.normalizedSourceExpression,
            'TargetExpression': imported.targetExpression,
            'LearningState': imported.learningState.name,
            'LearningTimestamp':
                imported.learningTimestamp?.millisecondsSinceEpoch,
          });
          await txn.insert(
            'StudySetMembership',
            {
              'VocabularyItemID': id,
              'StudySetID': targetStudySetId,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          continue;
        }

        final existingId = existing['VocabularyItemID'] as int;
        final existingTarget = existing['TargetExpression'] as String;
        if (existingTarget != imported.targetExpression) {
          final key = _conflictKey(imported);
          final resolvedTarget = resolvedTargetExpressions[key];
          if (resolvedTarget == null) {
            throw TransferValidationException(
              'A content conflict has not been resolved for ${imported.sourceExpression}.',
            );
          }
          if (resolvedTarget.trim().isEmpty) {
            throw TransferValidationException(
              'The resolved Target Expression for ${imported.sourceExpression} is empty.',
            );
          }
          await txn.update(
            'VocabularyItem',
            {
              'TargetExpression': resolvedTarget.trim(),
            },
            where: 'VocabularyItemID = ?',
            whereArgs: [existingId],
          );
        }

        if (_learningHistoryDiffers(existing, imported)) {
          if (!allowLearningHistoryOverwrite) {
            throw const TransferValidationException(
              'The transfer would overwrite existing learning information. Confirmation is required.',
            );
          }
          await txn.update(
            'VocabularyItem',
            {
              'LearningState': imported.learningState.name,
              'LearningTimestamp':
                  imported.learningTimestamp?.millisecondsSinceEpoch,
            },
            where: 'VocabularyItemID = ?',
            whereArgs: [existingId],
          );
        }

        await txn.insert(
          'StudySetMembership',
          {
            'VocabularyItemID': existingId,
            'StudySetID': targetStudySetId,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        existing = await _findVocabularyItem(
          txn,
          languageCombinationId: targetLanguageCombinationId,
          normalizedSourceExpression: imported.normalizedSourceExpression,
        );
      }
    });
  }

  Future<void> importEverything({required String filePath}) async {
    final package = _codec.decodeEverything(await File(filePath).readAsString());
    final db = await _databaseManager.database;

    await db.transaction((txn) async {
      final vocabularyCount = Sqflite.firstIntValue(
        await txn.rawQuery('SELECT COUNT(*) FROM VocabularyItem'),
      ) ?? 0;
      final membershipCount = Sqflite.firstIntValue(
        await txn.rawQuery('SELECT COUNT(*) FROM StudySetMembership'),
      ) ?? 0;
      final languageRows = await txn.query('LanguageCombination');
      final studySetRows = await txn.query('StudySet');
      final hasBootstrapLanguage = languageRows.length == 1 &&
          languageRows.first['SourceLanguage'] == '' &&
          languageRows.first['TargetLanguage'] == '';
      final hasBootstrapStudySet = studySetRows.length == 1 &&
          (studySetRows.first['IsDefaultStudySet'] as int? ?? 0) == 1 &&
          (studySetRows.first['StudySetName'] == 'Default' ||
              studySetRows.first['StudySetName'] == 'Repository');
      final isBootstrapEmptyTarget =
          vocabularyCount == 0 &&
          membershipCount == 0 &&
          hasBootstrapLanguage &&
          hasBootstrapStudySet;
      if (!isBootstrapEmptyTarget &&
          (vocabularyCount > 0 || membershipCount > 0 ||
              languageRows.isNotEmpty || studySetRows.isNotEmpty)) {
        throw const TransferValidationException(
          'Transfer Everything requires a new or empty target installation.',
        );
      }

      await txn.delete('StudySetMembership');
      await txn.delete('StudySet');
      await txn.delete('LanguageCombination');
      await txn.delete('Configuration');

      final languageIds = <String, int>{};
      for (final pair in package.languagePairs) {
        final id = await txn.insert('LanguageCombination', {
          'SourceLanguage': pair.sourceLanguage,
          'TargetLanguage': pair.targetLanguage,
        });
        languageIds[_pairKey(pair)] = id;
      }

      final studySetIds = <String, int>{};
      for (final studySet in package.studySets) {
        final pairId = languageIds[_pairKey(studySet.languagePair)];
        if (pairId == null) {
          throw const TransferValidationException(
            'A transferred Study Set refers to a missing Language Pair.',
          );
        }
        final id = await txn.insert('StudySet', {
          'LanguageCombinationID': pairId,
          'StudySetName': studySet.name,
          'StandardLearningWindowSize': studySet.standardLearningWindowSize,
          'IntenseLearningWindowSize': studySet.intenseLearningWindowSize,
          'MinimumInterval': studySet.minimumInterval,
          'IsDefaultStudySet': studySet.isDefaultStudySet ? 1 : 0,
        });
        studySetIds[_studySetKey(studySet)] = id;
      }

      final vocabularyIds = <String, int>{};
      for (final item in package.vocabularyItems) {
        final pairId = languageIds[_pairKey(item.languagePair)];
        if (pairId == null) {
          throw const TransferValidationException(
            'A transferred Vocabulary Item refers to a missing Language Pair.',
          );
        }
        final id = await txn.insert('VocabularyItem', {
          'LanguageCombinationID': pairId,
          'SourceExpression': item.sourceExpression,
          'NormalizedSourceExpression': item.normalizedSourceExpression,
          'TargetExpression': item.targetExpression,
          'LearningState': item.learningState.name,
          'LearningTimestamp': item.learningTimestamp?.millisecondsSinceEpoch,
        });
        vocabularyIds[_vocabularyKey(item)] = id;
      }

      for (final membership in package.memberships) {
        final studySetId = studySetIds[_membershipStudySetKey(membership)];
        final vocabularyId = vocabularyIds[_membershipVocabularyKey(membership)];
        if (studySetId == null || vocabularyId == null) {
          throw const TransferValidationException(
            'A transferred membership refers to missing data.',
          );
        }
        await txn.insert('StudySetMembership', {
          'VocabularyItemID': vocabularyId,
          'StudySetID': studySetId,
        });
      }

      await txn.insert('Configuration', {
        'ConfigurationID': 1,
        'CurrentLanguagePairID': null,
        'CurrentStudySetID': null,
      });
    });
  }

  TransferVocabularyItemData _vocabularyItemFromRow(
    Map<String, Object?> row,
    int languageCombinationId,
    Map<String, Object?> languageRow,
  ) {
    return TransferVocabularyItemData(
      languagePair: TransferLanguagePairData(
        sourceLanguage: languageRow['SourceLanguage'] as String,
        targetLanguage: languageRow['TargetLanguage'] as String,
      ),
      sourceExpression: row['SourceExpression'] as String,
      targetExpression: row['TargetExpression'] as String,
      learningState: LearningState.values.byName(row['LearningState'] as String),
      learningTimestamp: row['LearningTimestamp'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              row['LearningTimestamp'] as int,
            ),
    );
  }

  Future<Map<String, Object?>> _getStudySet(
    DatabaseExecutor db,
    int studySetId,
  ) async {
    final rows = await db.query(
      'StudySet',
      where: 'StudySetID = ?',
      whereArgs: [studySetId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const TransferValidationException('The target Study Set does not exist.');
    }
    return rows.first;
  }

  Future<Map<String, Object?>> _getLanguagePair(
    DatabaseExecutor db,
    int languageCombinationId,
  ) async {
    final rows = await db.query(
      'LanguageCombination',
      where: 'LanguageCombinationID = ?',
      whereArgs: [languageCombinationId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const TransferValidationException('The target Language Pair does not exist.');
    }
    return rows.first;
  }

  Future<Map<String, Object?>?> _findVocabularyItem(
    DatabaseExecutor db, {
    required int languageCombinationId,
    required String normalizedSourceExpression,
  }) async {
    final rows = await db.query(
      'VocabularyItem',
      where:
          'LanguageCombinationID = ? AND NormalizedSourceExpression = ?',
      whereArgs: [languageCombinationId, normalizedSourceExpression],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  void _ensureSameLanguagePair(
    TransferLanguagePairData packagePair,
    Map<String, Object?> targetPair,
  ) {
    if (packagePair.sourceLanguage != targetPair['SourceLanguage'] ||
        packagePair.targetLanguage != targetPair['TargetLanguage']) {
      throw const TransferValidationException(
        'The target Study Set belongs to a different Language Pair than the transfer.',
      );
    }
  }

  bool _learningHistoryDiffers(
    Map<String, Object?> existing,
    TransferVocabularyItemData imported,
  ) {
    final existingState = existing['LearningState'] as String;
    final existingTimestamp = existing['LearningTimestamp'] as int?;
    final importedTimestamp =
        imported.learningTimestamp?.millisecondsSinceEpoch;
    return existingState != imported.learningState.name ||
        existingTimestamp != importedTimestamp;
  }

  String _conflictKey(TransferVocabularyItemData item) =>
      '${item.languagePair.sourceLanguage}\u0000${item.languagePair.targetLanguage}\u0000${item.normalizedSourceExpression}';

  String _pairKey(TransferLanguagePairData pair) =>
      '${pair.sourceLanguage}\u0000${pair.targetLanguage}';

  String _studySetKey(TransferStudySetData studySet) =>
      '${_pairKey(studySet.languagePair)}\u0000${studySet.name}';

  String _vocabularyKey(TransferVocabularyItemData item) =>
      '${_pairKey(item.languagePair)}\u0000${item.normalizedSourceExpression}';

  String _membershipStudySetKey(TransferMembershipData membership) =>
      '${_pairKey(membership.languagePair)}\u0000${membership.studySetName}';

  String _membershipVocabularyKey(TransferMembershipData membership) =>
      '${_pairKey(membership.languagePair)}\u0000${membership.normalizedSourceExpression}';
}
