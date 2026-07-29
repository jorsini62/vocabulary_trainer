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

Future<List<StudySet>> getAllStudySets();
}