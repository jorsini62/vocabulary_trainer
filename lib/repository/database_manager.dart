import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseManager {
  DatabaseManager._();

  static final DatabaseManager instance = DatabaseManager._();

  static Database? _database;

  static const String _databaseName = 'vocabulary_trainer.db';
  static const int _databaseVersion = 5;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> deleteDevelopmentDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    await deleteDatabase(path);
    _database = null;
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 5) {
      final columns = await db.rawQuery('PRAGMA table_info(Configuration)');
      final hasCurrentStudySetId = columns.any(
        (column) => column['name'] == 'CurrentStudySetID',
      );

      if (!hasCurrentStudySetId) {
        await db.execute('''
ALTER TABLE Configuration
ADD COLUMN CurrentStudySetID INTEGER
REFERENCES StudySet (StudySetID)
''');
      }

      // Existing installations used CurrentLanguagePairID as the stored
      // context. Initialize the new Study Set context from that pair's
      // Repository Study Set, or its first Study Set if no Repository exists.
      await db.execute('''
UPDATE Configuration
SET CurrentStudySetID = (
  SELECT s.StudySetID
  FROM StudySet s
  WHERE s.LanguageCombinationID = Configuration.CurrentLanguagePairID
  ORDER BY s.IsDefaultStudySet DESC, s.StudySetID ASC
  LIMIT 1
)
WHERE CurrentStudySetID IS NULL
''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
CREATE TABLE LanguageCombination (
    LanguageCombinationID INTEGER PRIMARY KEY AUTOINCREMENT,
    SourceLanguage TEXT NOT NULL,
    TargetLanguage TEXT NOT NULL,
    UNIQUE (
        SourceLanguage,
        TargetLanguage
    )
)
''');

    await db.execute('''
CREATE UNIQUE INDEX IDX_LanguageCombination_LogicalIdentity
ON LanguageCombination (
    SourceLanguage,
    TargetLanguage
)
''');

    await db.execute('''
CREATE TABLE VocabularyItem (
    VocabularyItemID INTEGER PRIMARY KEY AUTOINCREMENT,
    LanguageCombinationID INTEGER NOT NULL,
    SourceExpression TEXT NOT NULL,
    NormalizedSourceExpression TEXT NOT NULL,
    TargetExpression TEXT NOT NULL,
    LearningState TEXT NOT NULL,
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
        ON DELETE CASCADE,
    UNIQUE (
        LanguageCombinationID,
        StudySetName
    )
)
''');

    await db.execute('''
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
''');

    await db.execute('''
CREATE TABLE Configuration (
    ConfigurationID INTEGER PRIMARY KEY
        CHECK (ConfigurationID = 1),
    CurrentLanguagePairID INTEGER,
    CurrentStudySetID INTEGER,
    FOREIGN KEY (CurrentLanguagePairID)
        REFERENCES LanguageCombination (LanguageCombinationID),
    FOREIGN KEY (CurrentStudySetID)
        REFERENCES StudySet (StudySetID)
)
''');

    await db.execute('''
CREATE UNIQUE INDEX IDX_VocabularyItem_LogicalIdentity
ON VocabularyItem (
    LanguageCombinationID,
    NormalizedSourceExpression
)
''');

    await db.execute('''
CREATE UNIQUE INDEX IDX_StudySet_LogicalIdentity
ON StudySet (
    LanguageCombinationID,
    StudySetName
)
''');

    await db.execute('''
CREATE INDEX IDX_StudySetMembership_VocabularyItem
ON StudySetMembership (
    VocabularyItemID
)
''');

    await db.execute('''
CREATE INDEX IDX_StudySetMembership_StudySet
ON StudySetMembership (
    StudySetID
)
''');

    // New databases start with no artificial Language Pair or Repository.
    // The first real Language Pair created by the user establishes its own
    // Repository Study Set.
    await db.insert('Configuration', {
      'ConfigurationID': 1,
      'CurrentLanguagePairID': null,
      'CurrentStudySetID': null,
    });
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
