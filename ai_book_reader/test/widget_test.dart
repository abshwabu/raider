import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_book_reader/app.dart';

void main() {
  testWidgets('App loads LibraryScreen placeholder smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: App(),
      ),
    );

    // Verify that the Library title and empty state text appear
    expect(find.text('My Library'), findsOneWidget);
    expect(find.text('No books yet'), findsOneWidget);
  });
}
