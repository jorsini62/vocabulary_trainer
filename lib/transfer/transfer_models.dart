import '../domain/learning_state.dart';

class TransferLanguagePairData {
  final String sourceLanguage;
  final String targetLanguage;

  const TransferLanguagePairData({
    required this.sourceLanguage,
    required this.targetLanguage,
  });
}

class TransferVocabularyItemData {
  final TransferLanguagePairData languagePair;
  final String sourceExpression;
  final String targetExpression;
  final LearningState learningState;
  final DateTime? learningTimestamp;

  const TransferVocabularyItemData({
    required this.languagePair,
    required this.sourceExpression,
    required this.targetExpression,
    required this.learningState,
    required this.learningTimestamp,
  });

  String get normalizedSourceExpression =>
      sourceExpression.trim().toLowerCase();
}

class TransferStudySetData {
  final TransferLanguagePairData languagePair;
  final String name;
  final bool isDefaultStudySet;
  final int standardLearningWindowSize;
  final int intenseLearningWindowSize;
  final int minimumInterval;

  const TransferStudySetData({
    required this.languagePair,
    required this.name,
    required this.isDefaultStudySet,
    required this.standardLearningWindowSize,
    required this.intenseLearningWindowSize,
    required this.minimumInterval,
  });
}

class TransferMembershipData {
  final TransferLanguagePairData languagePair;
  final String studySetName;
  final String normalizedSourceExpression;

  const TransferMembershipData({
    required this.languagePair,
    required this.studySetName,
    required this.normalizedSourceExpression,
  });
}

class TransferStudySetPackage {
  final int formatVersion;
  final String transferType;
  final DateTime exportedAt;
  final TransferLanguagePairData languagePair;
  final String sourceStudySetName;
  final List<TransferVocabularyItemData> vocabularyItems;

  const TransferStudySetPackage({
    required this.formatVersion,
    required this.transferType,
    required this.exportedAt,
    required this.languagePair,
    required this.sourceStudySetName,
    required this.vocabularyItems,
  });
}

class TransferEverythingPackage {
  final int formatVersion;
  final String transferType;
  final DateTime exportedAt;
  final List<TransferLanguagePairData> languagePairs;
  final List<TransferStudySetData> studySets;
  final List<TransferVocabularyItemData> vocabularyItems;
  final List<TransferMembershipData> memberships;

  const TransferEverythingPackage({
    required this.formatVersion,
    required this.transferType,
    required this.exportedAt,
    required this.languagePairs,
    required this.studySets,
    required this.vocabularyItems,
    required this.memberships,
  });
}

class TransferContentConflict {
  final TransferVocabularyItemData importedItem;
  final String existingTargetExpression;

  const TransferContentConflict({
    required this.importedItem,
    required this.existingTargetExpression,
  });
}

class TransferImportPlan {
  final List<TransferVocabularyItemData> newItems;
  final List<TransferVocabularyItemData> exactMatches;
  final List<TransferContentConflict> contentConflicts;
  final bool learningHistoryWillBeOverwritten;

  const TransferImportPlan({
    required this.newItems,
    required this.exactMatches,
    required this.contentConflicts,
    required this.learningHistoryWillBeOverwritten,
  });

  bool get requiresContentResolution => contentConflicts.isNotEmpty;
}
