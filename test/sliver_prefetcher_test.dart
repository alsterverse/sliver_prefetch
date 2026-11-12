import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliver_prefetch/sliver_prefetch.dart';

/// A 100-child list of 100 px rows in a 300 px viewport with no cache
/// extent, so exactly the rows on screen are laid out.
class _Harness extends StatefulWidget {
  const _Harness({
    super.key,
    required this.prefetcher,
    required this.controller,
    this.childCount = 100,
    this.grid = false,
  });

  final SliverPrefetcher prefetcher;
  final ScrollController controller;
  final int childCount;
  final bool grid;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  @override
  Widget build(BuildContext context) {
    final delegate = PrefetchingSliverChildBuilderDelegate(
      (context, index) => SizedBox(height: 100, child: Text('$index')),
      childCount: widget.childCount,
      prefetcher: widget.prefetcher,
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 300,
          height: 300,
          child: CustomScrollView(
            controller: widget.controller,
            // The replacement, scrollCacheExtent, is newer than the oldest
            // Flutter this package supports.
            // ignore: deprecated_member_use
            cacheExtent: 0,
            slivers: [
              if (widget.grid)
                SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                  ),
                  delegate: delegate,
                )
              else
                SliverFixedExtentList(itemExtent: 100, delegate: delegate),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  late List<List<int>> prefetched;
  late List<List<int>> cancelled;
  late ScrollController controller;

  SliverPrefetcher prefetcher({
    PrefetchExtent ahead = const PrefetchExtent.items(3),
    PrefetchExtent behind = PrefetchExtent.none,
    bool includeLaidOut = false,
  }) => SliverPrefetcher(
    ahead: ahead,
    behind: behind,
    includeLaidOut: includeLaidOut,
    onPrefetch: prefetched.add,
    onCancelPrefetch: cancelled.add,
  );

  setUp(() {
    prefetched = [];
    cancelled = [];
    controller = ScrollController();
  });

  tearDown(() => controller.dispose());

  testWidgets('reports the children just past the viewport on first layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(prefetcher: prefetcher(), controller: controller),
    );

    expect(prefetched, [
      [3, 4, 5],
    ]);
    expect(cancelled, isEmpty);
  });

  testWidgets('reports only new indices as the list scrolls forward', (
    tester,
  ) async {
    final p = prefetcher();
    await tester.pumpWidget(_Harness(prefetcher: p, controller: controller));
    prefetched.clear();

    controller.jumpTo(200);
    await tester.pump();

    // Rows 2-4 are laid out now; 3 and 4 arrived, 5 was already asked for.
    expect(p.laidOut, const IndexRange(2, 5));
    expect(prefetched, [
      [6, 7],
    ]);
    expect(cancelled, isEmpty);
  });

  testWidgets('turning around cancels what is now behind and looks the '
      'other way', (tester) async {
    final p = prefetcher();
    await tester.pumpWidget(_Harness(prefetcher: p, controller: controller));
    controller.jumpTo(1000);
    await tester.pump();
    prefetched.clear();
    cancelled.clear();

    controller.jumpTo(900);
    await tester.pump();

    expect(p.travel, ScrollTravel.backward);
    expect(cancelled, [
      [13, 14, 15],
    ]);
    expect(prefetched, [
      [8, 7, 6],
    ]);
  });

  testWidgets('a burst of layouts in one frame reports once', (tester) async {
    await tester.pumpWidget(
      _Harness(prefetcher: prefetcher(), controller: controller),
    );
    prefetched.clear();

    controller.jumpTo(100);
    controller.jumpTo(200);
    controller.jumpTo(300);
    await tester.pump();

    expect(prefetched, [
      [6, 7, 8],
    ]);
  });

  testWidgets('stops at the last child', (tester) async {
    await tester.pumpWidget(
      _Harness(prefetcher: prefetcher(), controller: controller, childCount: 5),
    );

    expect(prefetched, [
      [3, 4],
    ]);
  });

  testWidgets('includeLaidOut also reports the children on screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(
        prefetcher: prefetcher(includeLaidOut: true),
        controller: controller,
      ),
    );

    expect(prefetched, [
      [0, 1, 2, 3, 4, 5],
    ]);
  });

  testWidgets('layouts scales the look-ahead with a grid\'s columns', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(
        prefetcher: prefetcher(ahead: const PrefetchExtent.layouts(1)),
        controller: controller,
        grid: true,
      ),
    );

    // Three rows of three square cells fill the viewport.
    expect(prefetched, [
      [9, 10, 11, 12, 13, 14, 15, 16, 17],
    ]);
  });

  testWidgets('invalidate and reset report indices again', (tester) async {
    final p = prefetcher();
    await tester.pumpWidget(_Harness(prefetcher: p, controller: controller));
    prefetched.clear();

    p.invalidate([4]);
    await tester.pump();
    expect(prefetched, [
      [4],
    ]);

    p.reset();
    await tester.pump();
    expect(prefetched.last, [3, 4, 5]);
  });

  testWidgets('disabled reports nothing and re-enabling reports afresh', (
    tester,
  ) async {
    final p = prefetcher()..enabled = false;
    await tester.pumpWidget(_Harness(prefetcher: p, controller: controller));
    controller.jumpTo(200);
    await tester.pump();
    expect(prefetched, isEmpty);

    p.enabled = true;
    await tester.pump();
    expect(prefetched, [
      [5, 6, 7],
    ]);
  });

  testWidgets('the prefetcher outlives rebuilt delegates', (tester) async {
    final p = prefetcher();
    await tester.pumpWidget(_Harness(prefetcher: p, controller: controller));
    await tester.pumpWidget(
      _Harness(key: UniqueKey(), prefetcher: p, controller: controller),
    );

    expect(prefetched, [
      [3, 4, 5],
    ]);
  });

  testWidgets('dispose stops callbacks', (tester) async {
    final p = prefetcher();
    await tester.pumpWidget(_Harness(prefetcher: p, controller: controller));
    prefetched.clear();
    p.dispose();

    controller.jumpTo(500);
    await tester.pump();

    expect(prefetched, isEmpty);
  });
}
