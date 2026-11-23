import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliver_prefetch/sliver_prefetch.dart';

/// The README says the delegate also drives `ListView.custom` and
/// `GridView.custom`; these pin that.
void main() {
  late List<List<int>> prefetched;
  late ScrollController controller;
  late SliverPrefetcher prefetcher;

  setUp(() {
    prefetched = [];
    controller = ScrollController();
    prefetcher = SliverPrefetcher(
      ahead: const PrefetchExtent.items(3),
      onPrefetch: prefetched.add,
    );
  });

  tearDown(() {
    prefetcher.dispose();
    controller.dispose();
  });

  Widget viewport(Widget child) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox(width: 300, height: 300, child: child)),
      );

  PrefetchingSliverChildBuilderDelegate delegate() =>
      PrefetchingSliverChildBuilderDelegate(
        (context, index) => SizedBox(height: 100, child: Text('$index')),
        childCount: 100,
        prefetcher: prefetcher,
      );

  testWidgets('ListView.custom reports the rows past the viewport', (
    tester,
  ) async {
    await tester.pumpWidget(
      viewport(
        ListView.custom(
          controller: controller,
          // The replacement, scrollCacheExtent, is newer than the oldest
          // Flutter this package supports.
          // ignore: deprecated_member_use
          cacheExtent: 0,
          childrenDelegate: delegate(),
        ),
      ),
    );
    expect(prefetched, [
      [3, 4, 5],
    ]);

    prefetched.clear();
    controller.jumpTo(200);
    await tester.pump();
    expect(prefetched, [
      [6, 7],
    ]);
  });

  testWidgets('GridView.custom reports the cells past the viewport', (
    tester,
  ) async {
    await tester.pumpWidget(
      viewport(
        GridView.custom(
          controller: controller,
          // ignore: deprecated_member_use
          cacheExtent: 0,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
          ),
          childrenDelegate: delegate(),
        ),
      ),
    );
    // Three rows of three 100 px cells fill the viewport: 0-8 laid out.
    expect(prefetched, [
      [9, 10, 11],
    ]);
  });
}
