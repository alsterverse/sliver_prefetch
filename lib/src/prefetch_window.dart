/// @docImport 'sliver_prefetcher.dart';
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

import 'prefetch_extent.dart';

/// A half-open range of child indices, `[start, end)`.
@immutable
class IndexRange {
  /// Creates the range `[start, end)`.
  const IndexRange(this.start, this.end) : assert(start <= end);

  /// The range of children a sliver reported from
  /// `SliverChildDelegate.didFinishLayout`, whose bounds are both inclusive.
  const IndexRange.laidOut(int firstIndex, int lastIndex)
    : this(firstIndex, lastIndex + 1);

  /// The first index in the range.
  final int start;

  /// One past the last index in the range.
  final int end;

  /// How many indices the range holds.
  int get length => end - start;

  /// Whether the range holds no indices.
  bool get isEmpty => start == end;

  /// Whether [index] lies in the range.
  bool contains(int index) => index >= start && index < end;

  /// The indices in the range, in ascending order.
  Iterable<int> get indices sync* {
    for (var i = start; i < end; i++) {
      yield i;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is IndexRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'IndexRange($start, $end)';
}

/// Which way the indices on screen are moving.
enum ScrollTravel {
  /// Towards higher indices: down a vertical list, right in a horizontal one.
  forward,

  /// Towards lower indices.
  backward,
}

/// What a [SliverPrefetcher] reports after one layout.
@immutable
class PrefetchUpdate {
  /// Creates an update.
  const PrefetchUpdate({
    required this.prefetch,
    required this.cancel,
    required this.outstanding,
  });

  /// Indices that just became likely and have not been asked for yet, in
  /// the order they will come into view.
  final List<int> prefetch;

  /// Indices asked for earlier that are no longer likely to come into view
  /// soon, and did not come into view either.
  final List<int> cancel;

  /// Every index the prefetcher currently considers requested.
  final Set<int> outstanding;

  /// Whether the update reports nothing.
  bool get isEmpty => prefetch.isEmpty && cancel.isEmpty;
}

/// The pure calculation behind a [SliverPrefetcher], kept apart from frame
/// scheduling so it can be tested and reused on its own.
abstract final class PrefetchWindow {
  /// The indices worth having ready, given what is laid out now.
  ///
  /// [ahead] extends past the laid-out children in the direction of
  /// [travel], [behind] the other way. Both stop at index 0 and, when it is
  /// known, at [childCount]. The laid-out children themselves are included
  /// only when [includeLaidOut] is true.
  static Set<int> target({
    required IndexRange laidOut,
    required int? childCount,
    required ScrollTravel travel,
    required PrefetchExtent ahead,
    required PrefetchExtent behind,
    required bool includeLaidOut,
  }) {
    final aheadCount = ahead.resolve(laidOut.length);
    final behindCount = behind.resolve(laidOut.length);
    final (after, before) = switch (travel) {
      ScrollTravel.forward => (aheadCount, behindCount),
      ScrollTravel.backward => (behindCount, aheadCount),
    };

    final start = max(0, laidOut.start - before);
    final unbounded = laidOut.end + after;
    final end = childCount == null ? unbounded : min(unbounded, childCount);
    return {
      for (var i = start; i < end; i++)
        if (includeLaidOut || !laidOut.contains(i)) i,
    };
  }

  /// What changed between [outstanding] and the new [target].
  ///
  /// An outstanding index that is now laid out is retired without a cancel:
  /// it was prefetched for exactly this, and it arrived. The prefetch list is
  /// ordered by how soon each index comes into view under [travel].
  static PrefetchUpdate diff({
    required Set<int> outstanding,
    required Set<int> target,
    required IndexRange laidOut,
    required ScrollTravel travel,
  }) {
    final prefetch = target.difference(outstanding).toList()
      ..sort(_byArrival(laidOut, travel));
    final cancel =
        outstanding
            .difference(target)
            .where((i) => !laidOut.contains(i))
            .toList()
          ..sort();
    return PrefetchUpdate(
      prefetch: prefetch,
      cancel: cancel,
      outstanding: Set.unmodifiable(target),
    );
  }

  /// Laid-out children first, then those ahead nearest first, then those
  /// behind nearest first.
  static int Function(int, int) _byArrival(
    IndexRange laidOut,
    ScrollTravel travel,
  ) {
    int rank(int i) {
      if (laidOut.contains(i)) {
        return travel == ScrollTravel.forward
            ? i - laidOut.start
            : laidOut.end - 1 - i;
      }
      final isAhead = travel == ScrollTravel.forward
          ? i >= laidOut.end
          : i < laidOut.start;
      final distance = i >= laidOut.end ? i - laidOut.end : laidOut.start - i;
      // Laid-out children rank below any distance, ahead before behind.
      return laidOut.length + (isAhead ? 0 : 1 << 30) + distance;
    }

    return (a, b) => rank(a).compareTo(rank(b));
  }
}
