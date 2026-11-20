import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseManager {
  DatabaseManager._internal();

  static final DatabaseManager instance = DatabaseManager._internal();

  static Database? _database;

  static const String _databaseName = 'vocabulary_trainer.db';
  static const int _databaseVersion = 9;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<String> get databasePath async {
    final databasesPath = await getDatabasesPath();
    return p.join(databasesPath, _databaseName);
  }

  Future<Database> _openDatabase() async {
    final path = await databasePath;

    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> deleteDevelopmentDatabase() async {
    await close();

    final path = await databasePath;
    await deleteDatabase(path);
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE VocabularyItem
        ADD COLUMN LearningState TEXT NOT NULL DEFAULT 'Active'
      ''');

      await db.execute('''
        ALTER TABLE VocabularyItem
        ADD COLUMN LearningTimestamp INTEGER
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS StudySetMembership (
          StudySetID INTEGER NOT NULL,
          VocabularyItemID INTEGER NOT NULL,
          PRIMARY KEY (StudySetID, VocabularyItemID),
          FOREIGN KEY (StudySetID)
            REFERENCES StudySet (StudySetID)
            ON DELETE CASCADE,
          FOREIGN KEY (VocabularyItemID)
            REFERENCES VocabularyItem (VocabularyItemID)
            ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS IX_VocabularyItem_LanguageCombinationID
        ON VocabularyItem (LanguageCombinationID)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS IX_StudySetMembership_VocabularyItemID
        ON StudySetMembership (VocabularyItemID)
      ''');
    }

    if (oldVersion < 5) {
      await db.execute('''
        ALTER TABLE Configuration
        ADD COLUMN CurrentStudySetID INTEGER
      ''');

      await db.execute('''
        UPDATE Configuration
        SET CurrentStudySetID = (
          SELECT StudySetID
          FROM StudySet
          WHERE IsDefaultStudySet = 1
          LIMIT 1
        )
        WHERE CurrentStudySetID IS NULL
      ''');
    }

    if (oldVersion < 6) {
      final columns = await db.rawQuery(
        'PRAGMA table_info(StudySet)',
      );

      final hasName = columns.any(
        (column) => column['name'] == 'Name',
      );

      final hasStudySetName = columns.any(
        (column) => column['name'] == 'StudySetName',
      );

      if (hasName && !hasStudySetName) {
        await db.execute('''
          ALTER TABLE StudySet
          RENAME COLUMN Name TO StudySetName
        ''');
      }
    }

    if (oldVersion < 7) {
      final columns = await db.rawQuery(
        'PRAGMA table_info(Configuration)',
      );

      final hasBackupLocation = columns.any(
        (column) => column['name'] == 'BackupLocation',
      );

      if (!hasBackupLocation) {
        await db.execute('''
          ALTER TABLE Configuration
          ADD COLUMN BackupLocation TEXT
        ''');
      }
    }

    if (oldVersion < 8) {
      final columns = await db.rawQuery(
        'PRAGMA table_info(Configuration)',
      );

      final hasBackupBookmark = columns.any(
        (column) => column['name'] == 'BackupBookmark',
      );

      if (!hasBackupBookmark) {
        await db.execute('''
          ALTER TABLE Configuration
          ADD COLUMN BackupBookmark TEXT
        ''');
      }
    }

    if (oldVersion < 9) {
      final columns = await db.rawQuery(
        'PRAGMA table_info(Configuration)',
      );

      final hasLegacyLanguagePairId = columns.any(
        (column) => column['name'] == 'CurrentLanguagePairID',
      );
      final hasLanguageCombinationId = columns.any(
        (column) => column['name'] == 'CurrentLanguageCombinationID',
      );

      if (hasLegacyLanguagePairId && !hasLanguageCombinationId) {
        await db.execute('''
          ALTER TABLE Configuration
          RENAME COLUMN CurrentLanguagePairID
          TO CurrentLanguageCombinationID
        ''');
      } else if (!hasLanguageCombinationId) {
        await db.execute('''
          ALTER TABLE Configuration
          ADD COLUMN CurrentLanguageCombinationID INTEGER
        ''');
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE LanguageCombination (
        LanguageCombinationID INTEGER PRIMARY KEY AUTOINCREMENT,
        SourceLanguage TEXT NOT NULL,
        TargetLanguage TEXT NOT NULL,
        UNIQUE (SourceLanguage, TargetLanguage)
      )
    ''');

    await db.execute('''
      CREATE TABLE VocabularyItem (
        VocabularyItemID INTEGER PRIMARY KEY AUTOINCREMENT,
        LanguageCombinationID INTEGER NOT NULL,
        SourceExpression TEXT NOT NULL,
        NormalizedSourceExpression TEXT NOT NULL,
        TargetExpression TEXT NOT NULL,
        LearningState TEXT NOT NULL DEFAULT 'Active',
        LearningTimestamp INTEGER,
        FOREIGN KEY (LanguageCombinationID)
          REFERENCES LanguageCombination (LanguageCombinationID)
          ON DELETE CASCADE,
        UNIQUE (
          LanguageCombinationID,
          NormalizedSourceExpression
        )
      )
    ''');

    await db.execute('''
      CREATE TABLE StudySet (
        StudySetID INTEGER PRIMARY KEY AUTOINCREMENT,
        LanguageCombinationID INTEGER NOT NULL,
        StudySetName TEXT NOT NULL,
        StandardLearningWindowSize INTEGER NOT NULL,
        IntenseLearningWindowSize INTEGER NOT NULL,
        MinimumInterval INTEGER NOT NULL,
        IsDefaultStudySet INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (LanguageCombinationID)
          REFERENCES LanguageCombination (LanguageCombinationID)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE StudySetMembership (
        StudySetID INTEGER NOT NULL,
        VocabularyItemID INTEGER NOT NULL,
        PRIMARY KEY (StudySetID, VocabularyItemID),
        FOREIGN KEY (StudySetID)
          REFERENCES StudySet (StudySetID)
          ON DELETE CASCADE,
        FOREIGN KEY (VocabularyItemID)
          REFERENCES VocabularyItem (VocabularyItemID)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE Configuration (
        ConfigurationID INTEGER PRIMARY KEY,
        CurrentLanguageCombinationID INTEGER,
        CurrentStudySetID INTEGER,
        BackupLocation TEXT,
        BackupBookmark TEXT,
        FOREIGN KEY (CurrentLanguageCombinationID)
          REFERENCES LanguageCombination (LanguageCombinationID)
          ON DELETE SET NULL,
        FOREIGN KEY (CurrentStudySetID)
          REFERENCES StudySet (StudySetID)
          ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IX_VocabularyItem_LanguageCombinationID
      ON VocabularyItem (LanguageCombinationID)
    ''');

    await db.execute('''
      CREATE INDEX IX_StudySetMembership_VocabularyItemID
      ON StudySetMembership (VocabularyItemID)
    ''');

    await db.insert(
      'Configuration',
      {
        'ConfigurationID': 1,
        'CurrentLanguageCombinationID': null,
        'CurrentStudySetID': null,
        'BackupLocation': null,
        'BackupBookmark': null,
      },
    );
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}