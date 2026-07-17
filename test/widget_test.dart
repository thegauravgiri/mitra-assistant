import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mitra_assistant/app.dart';

void main() {
  testWidgets('MitraApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MitraApp(),
      ),
    );

    expect(find.text('Mitra Assistant'), findsOneWidget);
  });
}
