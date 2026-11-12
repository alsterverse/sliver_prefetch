// Pins the behaviour the README's "Caveats" section describes, so the
// documentation fails loudly if Flutter or the package changes under it.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliver_prefetch/sliver_prefetch.dart';

class _KeptAlive extends StatefulWidget {
  const _KeptAlive({required this.index});

  final int index;

  @override
  State<_KeptAlive> createState() => _KeptAliveState();
}

class _KeptAliveState extends State<_KeptAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Text('${widget.index}');
  }
}

class _Counter extends StatefulWidget {
  const _Counter({super.key, required this.id});

  final String id;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => _taps++),
    child: Text('${widget.id}: $_taps'),
  );
}

Widget _list({
  required SliverPrefetcher prefetcher,
  required NullableIndexedWidgetBuilder builder,
  int? childCount,
  ScrollController? controller,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: SizedBox(
      height: 300,
      child: CustomScrollView(
        controller: controller,
        // ignore: deprecated_member_use
        cacheExtent: 0,
        slivers: [
          SliverFixedExtentList(
            itemExtent: 100,
            delegate: PrefetchingSliverChildBuilderDelegate(
              builder,
              childCount: childCount,
              prefetcher: prefetcher,
            ),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  late List<List<int>> prefetched;

  SliverPrefetcher prefetcher() => SliverPrefetcher(
    ahead: const PrefetchExtent.items(3),
    onPrefetch: prefetched.add,
  );

  setUp(() => prefetched = []);

  testWidgets('a kept-alive child widens the reported range to reach it', (
    tester,
  ) async {
    final p = prefetcher();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _list(
        prefetcher: p,
        controller: controller,
        childCount: 100,
        builder: (context, index) =>
            index == 0 ? const _KeptAlive(index: 0) : Text('$index'),
      ),
    );

    controller.jumpTo(2000);
    await tester.pump();

    // Rows 20-22 are on screen, but row 0 is still in the element map.
    expect(find.text('20'), findsOneWidget);
    expect(p.laidOut, const IndexRange(0, 23));
  });

  testWidgets('a sliver with no children reports nothing', (tester) async {
    await tester.pumpWidget(
      _list(
        prefetcher: prefetcher(),
        childCount: 0,
        builder: (context, index) => Text('$index'),
      ),
    );

    expect(prefetched, isEmpty);
  });

  testWidgets('with an unknown count and no children, nothing is reported', (
    tester,
  ) async {
    final p = prefetcher();
    await tester.pumpWidget(
      _list(prefetcher: p, builder: (context, index) => null),
    );

    expect(p.laidOut, isNull);
    expect(prefetched, isEmpty);
  });

  testWidgets('a sliver below the viewport builds child 0 and looks ahead '
      'from it', (tester) async {
    final above = SliverPrefetcher(onPrefetch: (_) {});
    final belowPrefetched = <List<int>>[];
    final below = SliverPrefetcher(
      ahead: const PrefetchExtent.items(3),
      onPrefetch: belowPrefetched.add,
    );
    SliverFixedExtentList list(SliverPrefetcher p) => SliverFixedExtentList(
      itemExtent: 100,
      delegate: PrefetchingSliverChildBuilderDelegate(
        (context, index) => Text('$index'),
        childCount: 50,
        prefetcher: p,
      ),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: CustomScrollView(
          // ignore: deprecated_member_use
          cacheExtent: 0,
          slivers: [list(above), list(below)],
        ),
      ),
    );

    // Flutter builds the first child of a sliver waiting below the viewport,
    // so its look-ahead is ready before it scrolls in.
    expect(below.laidOut, const IndexRange(0, 1));
    expect(belowPrefetched, [
      [1, 2, 3],
    ]);
  });

  testWidgets('a sliver scrolled out and back keeps its state and direction', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final cancelled = <List<int>>[];
    final p = SliverPrefetcher(
      ahead: const PrefetchExtent.items(3),
      onPrefetch: prefetched.add,
      onCancelPrefetch: cancelled.add,
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: CustomScrollView(
          controller: controller,
          // ignore: deprecated_member_use
          cacheExtent: 0,
          slivers: [
            SliverFixedExtentList(
              itemExtent: 100,
              delegate: PrefetchingSliverChildBuilderDelegate(
                (context, index) => Text('$index'),
                childCount: 20,
                prefetcher: p,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 5000)),
          ],
        ),
      ),
    );
    controller.jumpTo(1400);
    await tester.pump();
    expect(p.laidOut, const IndexRange(14, 20));

    // Past the end of the list: nothing of it is built any more.
    controller.jumpTo(4000);
    await tester.pump();
    expect(p.laidOut, const IndexRange(14, 20));

    prefetched.clear();
    cancelled.clear();
    // Back up into the last rows, which is travelling backward.
    controller.jumpTo(1700);
    await tester.pump();
    expect(p.laidOut, const IndexRange(17, 20));
    expect(p.travel, ScrollTravel.backward);
    expect(prefetched, [
      [16, 15, 14],
    ]);
    expect(cancelled, isEmpty);
  });

  testWidgets('a keyed child that moves keeps its state', (tester) async {
    final p = prefetcher();
    var order = ['a', 'b', 'c'];
    late StateSetter rebuild;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return CustomScrollView(
              slivers: [
                SliverFixedExtentList(
                  itemExtent: 100,
                  delegate: PrefetchingSliverChildBuilderDelegate(
                    (context, index) =>
                        _Counter(key: ValueKey(order[index]), id: order[index]),
                    findChildIndexCallback: (key) =>
                        order.indexOf((key as ValueKey<String>).value),
                    childCount: order.length,
                    prefetcher: p,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('a: 0'));
    await tester.pump();
    expect(find.text('a: 1'), findsOneWidget);

    rebuild(() => order = ['c', 'b', 'a']);
    await tester.pump();

    // The tap count moved with 'a' to the last row.
    expect(find.text('a: 1'), findsOneWidget);
    expect(tester.getTopLeft(find.text('a: 1')).dy, 200);
  });

  testWidgets('a callback may name an index the app already has', (
    tester,
  ) async {
    final p = SliverPrefetcher(
      includeLaidOut: true,
      onPrefetch: prefetched.add,
    );
    await tester.pumpWidget(
      _list(
        prefetcher: p,
        childCount: 10,
        builder: (context, index) => Text('$index'),
      ),
    );

    // The prefetcher has no idea what is loaded: the rows on screen are named
    // even though the builder plainly had what it needed to draw them.
    expect(prefetched.single, containsAll([0, 1, 2]));
  });
}
