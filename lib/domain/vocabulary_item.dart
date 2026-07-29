import 'learning_state.dart';

class VocabularyItem {
  final int? id;

  final String sourceLanguage;
  final String targetLanguage;

  final String sourceExpression;
  final String targetExpression;

  final LearningState? learningState;
  final DateTime? reviewTimestamp;
 
  VocabularyItem({
    this.id,

    required this.sourceLanguage,
    required this.targetLanguage,

    required this.sourceExpression,
    required this.targetExpression,

    required this.learningState,
    required this.reviewTimestamp,
  });
}