import 'package:flutter_test/flutter_test.dart';
import 'package:sliver_prefetch/sliver_prefetch.dart';

void main() {
  group('PrefetchExtent', () {
    test('items is fixed', () {
      expect(const PrefetchExtent.items(4).resolve(100), 4);
    });

    test('layouts scales with the laid-out count and rounds up', () {
      expect(const PrefetchExtent.layouts(1.5).resolve(9), 14);
      expect(const PrefetchExtent.layouts(0).resolve(9), 0);
    });
  });

  group('PrefetchWindow.target', () {
    Set<int> target({
      IndexRange laidOut = const IndexRange(10, 15),
      int? childCount = 100,
      ScrollTravel travel = ScrollTravel.forward,
      PrefetchExtent ahead = const PrefetchExtent.items(3),
      PrefetchExtent behind = PrefetchExtent.none,
      bool includeLaidOut = false,
    }) => PrefetchWindow.target(
      laidOut: laidOut,
      childCount: childCount,
      travel: travel,
      ahead: ahead,
      behind: behind,
      includeLaidOut: includeLaidOut,
    );

    test('looks ahead past the end when travelling forward', () {
      expect(target(), {15, 16, 17});
    });

    test('looks ahead past the start when travelling backward', () {
      expect(target(travel: ScrollTravel.backward), {7, 8, 9});
    });

    test('behind looks the other way', () {
      expect(target(behind: const PrefetchExtent.items(2)), {8, 9, 15, 16, 17});
    });

    test('stops at zero and at the child count', () {
      expect(
        target(
          laidOut: const IndexRange(0, 3),
          childCount: 5,
          behind: const PrefetchExtent.items(4),
        ),
        {3, 4},
      );
    });

    test('an unknown child count does not bound the window', () {
      expect(target(childCount: null, ahead: const PrefetchExtent.items(2)), {
        15,
        16,
      });
    });

    test('includes the laid-out children only when asked', () {
      expect(target(includeLaidOut: true, ahead: PrefetchExtent.none), {
        10,
        11,
        12,
        13,
        14,
      });
    });

    test('layouts resolves against the laid-out count', () {
      expect(target(ahead: const PrefetchExtent.layouts(1)), {
        15,
        16,
        17,
        18,
        19,
      });
    });
  });

  group('PrefetchWindow.diff', () {
    test('reports new indices in arrival order', () {
      final update = PrefetchWindow.diff(
        outstanding: const {},
        target: {9, 8, 17, 15, 16},
        laidOut: const IndexRange(10, 15),
        travel: ScrollTravel.forward,
      );
      expect(update.prefetch, [15, 16, 17, 9, 8]);
      expect(update.cancel, isEmpty);
    });

    test('arrival order flips when travelling backward', () {
      final update = PrefetchWindow.diff(
        outstanding: const {},
        target: {9, 8, 15},
        laidOut: const IndexRange(10, 15),
        travel: ScrollTravel.backward,
      );
      expect(update.prefetch, [9, 8, 15]);
    });

    test('laid-out children come first, nearest the leading edge', () {
      final update = PrefetchWindow.diff(
        outstanding: const {},
        target: {16, 11, 10, 15},
        laidOut: const IndexRange(10, 15),
        travel: ScrollTravel.backward,
      );
      expect(update.prefetch, [11, 10, 15, 16]);
    });

    test('does not report outstanding indices again', () {
      final update = PrefetchWindow.diff(
        outstanding: {15, 16},
        target: {15, 16, 17},
        laidOut: const IndexRange(10, 15),
        travel: ScrollTravel.forward,
      );
      expect(update.prefetch, [17]);
      expect(update.outstanding, {15, 16, 17});
    });

    test('cancels indices that left the window without being laid out', () {
      final update = PrefetchWindow.diff(
        outstanding: {7, 8, 9},
        target: {15, 16},
        laidOut: const IndexRange(10, 15),
        travel: ScrollTravel.forward,
      );
      expect(update.cancel, [7, 8, 9]);
    });

    test('retires indices that were laid out, without cancelling', () {
      final update = PrefetchWindow.diff(
        outstanding: {15, 16},
        target: {17, 18},
        laidOut: const IndexRange(12, 17),
        travel: ScrollTravel.forward,
      );
      expect(update.cancel, isEmpty);
      expect(update.prefetch, [17, 18]);
      expect(update.outstanding, {17, 18});
    });
  });
}
