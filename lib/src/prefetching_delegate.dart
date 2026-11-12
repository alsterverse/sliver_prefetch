import 'package:flutter/widgets.dart';

import 'sliver_prefetcher.dart';

/// Reports every layout of the sliver it belongs to to a [SliverPrefetcher].
///
/// Mix it into any [SliverChildDelegate]. `RenderSliverList` and
/// `RenderSliverGrid` call `didFinishLayout` after each layout pass with the
/// range of children they built, cache extent included, so this works with
/// any list or grid layout, custom grid delegates too.
///
/// The reported range comes from the sliver's element map, which also holds
/// children kept alive with `AutomaticKeepAlive`. A kept-alive child far from
/// the viewport widens the range to reach it, so avoid keep-alives on slivers
/// you prefetch for.
mixin SliverPrefetchingDelegateMixin on SliverChildDelegate {
  /// The prefetcher this delegate reports to.
  SliverPrefetcher get prefetcher;

  @override
  void didFinishLayout(int firstIndex, int lastIndex) {
    super.didFinishLayout(firstIndex, lastIndex);
    prefetcher.reportLayout(
      firstIndex,
      lastIndex,
      childCount: estimatedChildCount,
    );
  }
}

/// A [SliverChildBuilderDelegate] that reports its layouts to [prefetcher].
class PrefetchingSliverChildBuilderDelegate extends SliverChildBuilderDelegate
    with SliverPrefetchingDelegateMixin {
  /// Creates a builder delegate that drives [prefetcher].
  ///
  /// Every other argument is passed through to [SliverChildBuilderDelegate].
  PrefetchingSliverChildBuilderDelegate(
    super.builder, {
    required this.prefetcher,
    super.findChildIndexCallback,
    super.childCount,
    super.addAutomaticKeepAlives,
    super.addRepaintBoundaries,
    super.addSemanticIndexes,
    super.semanticIndexCallback,
    super.semanticIndexOffset,
  });

  @override
  final SliverPrefetcher prefetcher;
}
