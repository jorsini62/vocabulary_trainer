import '../domain/vocabulary_item.dart';

abstract class VocabularyRepository {
  Future<int> insertVocabularyItem(VocabularyItem item);

  Future<VocabularyItem?> getVocabularyItemById(int id);

  Future<List<VocabularyItem>> getVocabularyItemsByLanguageCombinationId(
    int languageCombinationId,
  );

  Future<void> updateVocabularyItem(VocabularyItem item);

  Future<void> updateVocabularyExpressions(
    int vocabularyItemId,
    String sourceExpression,
    String targetExpression,
  );

  Future<void> deleteVocabularyItem(int id);

  Future<bool> sourceExpressionExists(
    int languageCombinationId,
    String sourceExpression,
  );

  Future<int?> getVocabularyItemIdBySourceExpression(
    int languageCombinationId,
    String sourceExpression,
  );
}
