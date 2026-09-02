import '../domain/study_set.dart';

abstract class StudySetRepository {
  Future<int> insertStudySet(StudySet studySet);

  Future<StudySet?> getStudySetById(int id);

  Future<void> updateStudySet(StudySet studySet);

  Future<void> deleteStudySet(int id);

Future<void> addVocabularyItemToStudySet(
  int vocabularyItemId,
  int studySetId,
);

Future<void> removeVocabularyItemFromStudySet(
  int vocabularyItemId,
  int studySetId,
);

Future<List<StudySet>> getStudySetsByLanguageCombinationId(
  int languageCombinationId,
);

Future<List<StudySet>> getAllStudySets();

Future<StudySet?> getDefaultStudySet(
  int languageCombinationId,
);

Future<Map<String, int>> getStudySetStatistics(int studySetId);
}