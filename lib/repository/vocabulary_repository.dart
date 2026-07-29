import '../models/vocabulary_item.dart';

abstract class VocabularyRepository {
  Future<int> insertVocabularyItem(VocabularyItem item);

  Future<VocabularyItem?> getVocabularyItemById(int id);

  Future<void> updateVocabularyItem(VocabularyItem item);

  Future<void> deleteVocabularyItem(int id);
}