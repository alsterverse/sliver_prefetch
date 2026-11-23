// Compares two ways of getting about 2000 px of look-ahead on a grid: raising
// the viewport's cache extent, which builds the children in that range, and
// sliver_prefetch on the default cache extent, which only reports their
// indices. A baseline with neither is included.
//
// Run with `flutter test tool/cache_extent_benchmark_test.dart`. It prints a
// Markdown table. Time is faked and the tiles are trivial, so it counts
// work (builds and live tiles) rather than timing it.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliver_prefetch/sliver_prefetch.dart';

const _viewport = Size(400, 800);
const _columns = 3;
const _lookAhead = 2000.0;

/// Square tiles: a row is as tall as the viewport is wide over the columns.
const _rowExtent = 400 / _columns;

/// Frames of scrolling at 30 px each, as at 1800 px/s and 60 fps.
const _scrollFrames = 300;
const _scrollStep = 30.0;
const _jumpTo = 60000.0;

class _Counters {
  int builds = 0;
  int live = 0;
  int peakLive = 0;
  int prefetched = 0;
}

class _Tile extends StatefulWidget {
  const _Tile(this.counters);

  final _Counters counters;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  @override
  void initState() {
    super.initState();
    final c = widget.counters;
    c.live++;
    if (c.live > c.peakLive) c.peakLive = c.live;
  }

  @override
  void dispose() {
    widget.counters.live--;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.counters.builds++;
    return const ColoredBox(color: Color(0xFF2A3038));
  }
}

enum _Setup {
  baseline('Default cache extent (250 px), no look-ahead'),
  cacheExtent('`cacheExtent: 2000`'),
  prefetch('Default cache extent + sliver_prefetch, 2000 px ahead');

  const _Setup(this.label);

  final String label;
}

class _Result {
  _Result(this.setup);

  final _Setup setup;
  int firstFrameBuilds = 0;
  int liveWhileScrolling = 0;
  int buildsPerScrollFrame = 0;
  int jumpFrameBuilds = 0;
  int peakLive = 0;
  int prefetchedAhead = 0;
}

Future<_Result> _run(WidgetTester tester, _Setup setup) async {
  final counters = _Counters();
  final controller = ScrollController();
  final rowsAhead = (_lookAhead / _rowExtent).ceil();
  final prefetcher = SliverPrefetcher(
    ahead: PrefetchExtent.items(rowsAhead * _columns),
    onPrefetch: (indices) => counters.prefetched += indices.length,
  );
  final result = _Result(setup);

  Widget tile(BuildContext context, int index) => _Tile(counters);
  final delegate = setup == _Setup.prefetch
      ? PrefetchingSliverChildBuilderDelegate(
          tile,
          childCount: 100000,
          prefetcher: prefetcher,
        )
      : SliverChildBuilderDelegate(tile, childCount: 100000);

  tester.view
    ..physicalSize = _viewport
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: CustomScrollView(
        controller: controller,
        // scrollCacheExtent replaces it but is newer than the oldest Flutter
        // this package supports.
        // ignore: deprecated_member_use
        cacheExtent: setup == _Setup.cacheExtent ? _lookAhead : null,
        slivers: [
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columns,
            ),
            delegate: delegate,
          ),
        ],
      ),
    ),
  );
  result.firstFrameBuilds = counters.builds;

  // Settle into a steady scroll first, then measure a stretch of it.
  for (var i = 0; i < 50; i++) {
    controller.jumpTo(controller.offset + _scrollStep);
    await tester.pump();
  }
  final before = counters.builds;
  for (var i = 0; i < _scrollFrames; i++) {
    controller.jumpTo(controller.offset + _scrollStep);
    await tester.pump();
  }
  result.buildsPerScrollFrame =
      ((counters.builds - before) / _scrollFrames).round();
  result.liveWhileScrolling = counters.live;
  result.prefetchedAhead = prefetcher.outstanding.length;

  final beforeJump = counters.builds;
  controller.jumpTo(_jumpTo);
  await tester.pump();
  result.jumpFrameBuilds = counters.builds - beforeJump;
  result.peakLive = counters.peakLive;

  prefetcher.dispose();
  controller.dispose();
  return result;
}

void main() {
  final results = <_Result>[];

  for (final setup in _Setup.values) {
    testWidgets(setup.name, (tester) async {
      results.add(await _run(tester, setup));
    });
  }

  tearDownAll(() {
    final rows = [
      '| | ${results.map((r) => r.setup.label).join(' | ')} |',
      '| --- |${' ---: |' * results.length}',
      for (final (label, value) in <(String, int Function(_Result))>[
        ('Tiles built for the first frame', (r) => r.firstFrameBuilds),
        ('Tiles alive while scrolling', (r) => r.liveWhileScrolling),
        ('Tiles built per frame of scrolling', (r) => r.buildsPerScrollFrame),
        ('Tiles built in the frame after a jump', (r) => r.jumpFrameBuilds),
        ('Indices reported ahead, not built', (r) => r.prefetchedAhead),
      ])
        '| $label | ${results.map((r) => value(r)).join(' | ')} |',
    ];
    // ignore: avoid_print
    print(rows.join('\n'));
  });
}
