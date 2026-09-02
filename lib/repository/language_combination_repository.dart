import '../domain/language_combination.dart';

abstract class LanguageCombinationRepository {
  Future<int> insert(LanguageCombination languageCombination);

  Future<LanguageCombination?> getById(int id);

  Future<List<LanguageCombination>> getAll();

  Future<LanguageCombination?> getFirst();

  Future<void> update(LanguageCombination languageCombination);

  Future<void> delete(int id);
}