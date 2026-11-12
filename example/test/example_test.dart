import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliver_prefetch_example/main.dart';

void main() {
  testWidgets('cells load, and the look-ahead toggles', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('…'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('0'), findsOneWidget);
    expect(find.textContaining('Pages fetched: '), findsOneWidget);

    await tester.tap(find.textContaining('Look ahead'));
    await tester.pump();
    expect(find.text('Look ahead: off'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
  });
}
