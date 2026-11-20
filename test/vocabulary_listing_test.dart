import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_trainer/domain/learning_state.dart';
import 'package:vocabulary_trainer/domain/vocabulary_item.dart';
import 'package:vocabulary_trainer/utils/vocabulary_listing.dart';

VocabularyItem item(String source, {String target = 'translation', int? id}) =>
    VocabularyItem(
      id: id,
      languageCombinationId: 1,
      sourceExpression: source,
      targetExpression: target,
      learningState: LearningState.newItem,
      learningTimestamp: null,
    );

List<String> sources(Iterable<VocabularyItem> items) =>
    items.map((item) => item.sourceExpression).toList();

void main() {
  test('normalizes all six vowels, uppercase and decomposed macrons', () {
    expect(normalizeVocabularyExpression('ĀĒĪŌŪȲāēīōūȳ'), 'aeiouyaeiouy');
    expect(
      normalizeVocabularyExpression(
        'A\u0304E\u0304I\u0304O\u0304U\u0304Y\u0304',
      ),
      'aeiouy',
    );
    expect(normalizeVocabularyExpression('é'), 'é');
  });

  test('sorts complete expressions ignoring macrons and case', () {
    final input = [
      'ȳpsilon',
      'ūnus',
      'ōvum',
      'īra',
      'ēdo',
      'az',
      'āba',
      'Abacus',
    ];
    expect(sources(filterVocabularyForListing(input.map(item), '')), [
      'āba',
      'Abacus',
      'az',
      'ēdo',
      'īra',
      'ōvum',
      'ūnus',
      'ȳpsilon',
    ]);
  });

  test('prefix filters both expressions and keeps normalized ordering', () {
    final input = [
      item('officium'),
      item('citō'),
      item('incidere'),
      item('cīvis'),
      item('cibus'),
      item('alius', target: 'City'),
    ];
    expect(sources(filterVocabularyForListing(input, ' CI ')), [
      'alius',
      'cibus',
      'citō',
      'cīvis',
    ]);
  });

  test('plain, precomposed, decomposed and uppercase queries agree', () {
    final input = [
      item('āmīcus'),
      item('a\u0304mi\u0304ca'),
      item('AMITA'),
      item('inamicus'),
    ];
    final expected = ['a\u0304mi\u0304ca', 'āmīcus', 'AMITA'];
    for (final query in ['ami', 'āmī', 'A\u0304MI\u0304', ' AMI ']) {
      expect(sources(filterVocabularyForListing(input, query)), expected);
    }
    expect(
      sources(filterVocabularyForListing([item('x', target: 'ĀMĪCUS')], 'ami')),
      ['x'],
    );
  });

  test(
    'empty and whitespace queries return all items without mutating input',
    () {
      final input = [item('ūnus'), item('āba')];
      for (final query in ['', '  \t\n']) {
        final result = filterVocabularyForListing(input, query);
        expect(sources(result), ['āba', 'ūnus']);
        expect(identical(result.last, input.first), isTrue);
      }
      expect(sources(input), ['ūnus', 'āba']);
      expect(input.last.sourceExpression, 'āba');
      expect(filterVocabularyForListing(input, 'missing'), isEmpty);
    },
  );

  test(
    'normalized duplicates use spelling then ID regardless of input order',
    () {
      final input = [
        item('ā', id: 4),
        item('a', id: 3),
        item('A', id: 5),
        item('a\u0304', id: 6),
        item('a', id: 1),
      ];
      for (final items in [input, input.reversed]) {
        final result = filterVocabularyForListing(items, 'a');
        expect(result.map((item) => item.id), [5, 1, 3, 6, 4]);
      }
    },
  );
}
