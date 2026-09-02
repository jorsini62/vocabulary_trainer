import 'learning_state.dart';

class VocabularyItem {
  final int? id;

  final int languageCombinationId;

  final String sourceExpression;
  final String targetExpression;

  final LearningState learningState;

  final DateTime? learningTimestamp;

  VocabularyItem({
    this.id,
    required this.languageCombinationId,
    required this.sourceExpression,
    required this.targetExpression,
    required this.learningState,
    required this.learningTimestamp,
  });
}