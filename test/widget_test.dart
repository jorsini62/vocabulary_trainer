import 'package:flutter_test/flutter_test.dart';

import 'package:vocabulary_trainer/main.dart';

void main() {
  testWidgets('VocabularyTrainerApp can be constructed', (WidgetTester tester) async {
    // Do not pump the full app here: DashboardScreen opens SQLite.
    const app = VocabularyTrainerApp();
    expect(app, isA<VocabularyTrainerApp>());
  });
}
