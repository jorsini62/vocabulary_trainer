import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseManager {
  DatabaseManager._();

  static final DatabaseManager instance = DatabaseManager._();

  static Database? _database;

  static const String _databaseName = 'vocabulary_trainer.db';
  static const int _databaseVersion = 1;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();

    final path = join(
      databasesPath,
      _databaseName,
    );

    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute(
      'PRAGMA foreign_keys = ON;',
    );
  }

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Version 1 requires no schema migration.
  }

  Future<void> _onCreate(
    Database db,
    int version,
  ) async {
    await db.execute(
      '''
CREATE TABLE VocabularyItem (
    VocabularyItemID INTEGER PRIMARY KEY AUTOINCREMENT,
    SourceLanguage TEXT NOT NULL,
    TargetLanguage TEXT NOT NULL,
    SourceExpression TEXT NOT NULL,
    NormalizedSourceExpression TEXT NOT NULL,
    TargetExpression TEXT NOT NULL,
    LearningState TEXT NOT NULL,
    LearningTimestamp INTEGER NOT NULL,

    UNIQUE (
        SourceLanguage,
        TargetLanguage,
        NormalizedSourceExpression
    )
)
''',
    );

    await db.execute(
      '''
CREATE TABLE StudySet (
    StudySetID INTEGER PRIMARY KEY AUTOINCREMENT,
    SourceLanguage TEXT NOT NULL,
    TargetLanguage TEXT NOT NULL,
    StudySetName TEXT NOT NULL,
    LearningWindowSize INTEGER NOT NULL,
    IsDefaultStudySet INTEGER NOT NULL DEFAULT 0,

    UNIQUE (
        SourceLanguage,
        TargetLanguage,
        StudySetName
    )
)
''',
    );

    await db.execute(
      '''
CREATE TABLE StudySetMembership (
    VocabularyItemID INTEGER NOT NULL,
    StudySetID INTEGER NOT NULL,

    PRIMARY KEY (
        VocabularyItemID,
        StudySetID
    ),

    FOREIGN KEY (VocabularyItemID)
        REFERENCES VocabularyItem (VocabularyItemID)
        ON DELETE CASCADE,

    FOREIGN KEY (StudySetID)
        REFERENCES StudySet (StudySetID)
        ON DELETE CASCADE
)
''',
    );

    await db.execute(
      '''
CREATE TABLE Configuration (
    ConfigurationID INTEGER PRIMARY KEY
        CHECK (ConfigurationID = 1),

    CurrentStudySetID INTEGER NOT NULL,

    FOREIGN KEY (CurrentStudySetID)
        REFERENCES StudySet (StudySetID)
)
''',
    );

        await db.execute(
      '''
CREATE UNIQUE INDEX IDX_VocabularyItem_LogicalIdentity
ON VocabularyItem (
    SourceLanguage,
    TargetLanguage,
    NormalizedSourceExpression
)
''',
    );

    await db.execute(
      '''
CREATE UNIQUE INDEX IDX_StudySet_LogicalIdentity
ON StudySet (
    SourceLanguage,
    TargetLanguage,
    StudySetName
)
''',
    );

    await db.execute(
      '''
CREATE INDEX IDX_StudySetMembership_VocabularyItem
ON StudySetMembership (
    VocabularyItemID
)
''',
    );

    await db.execute(
      '''
CREATE INDEX IDX_StudySetMembership_StudySet
ON StudySetMembership (
    StudySetID
)
''',
    );

    await db.execute(
      '''
CREATE INDEX IDX_Configuration_CurrentStudySet
ON Configuration (
    CurrentStudySetID
)
''',
    );

        final defaultStudySetId = await db.insert(
      'StudySet',
      {
        'SourceLanguage': '',
        'TargetLanguage': '',
        'StudySetName': 'Default',
        'LearningWindowSize': 100,
        'IsDefaultStudySet': 1,
      },
    );

    await db.insert(
      'Configuration',
      {
        'CurrentStudySetID': defaultStudySetId,
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