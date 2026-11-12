/// @docImport 'sliver_prefetcher.dart';
library;

/// How far beyond the laid-out children a [SliverPrefetcher] looks.
sealed class PrefetchExtent {
  const PrefetchExtent();

  /// A fixed number of children.
  const factory PrefetchExtent.items(int count) = _ItemsExtent;

  /// A multiple of however many children the sliver currently lays out.
  ///
  /// The laid-out range includes the scroll view's cache extent, not only the
  /// children on screen, so `PrefetchExtent.layouts(1)` looks ahead by one
  /// viewport plus the cache extent. Scales with the screen, the item size
  /// and the grid's column count without being told about any of them.
  const factory PrefetchExtent.layouts(double factor) = _LayoutsExtent;

  /// No look-ahead at all.
  static const PrefetchExtent none = _ItemsExtent(0);

  /// The number of children this extent covers when [laidOutCount] children
  /// are currently laid out.
  int resolve(int laidOutCount);
}

final class _ItemsExtent extends PrefetchExtent {
  const _ItemsExtent(this.count) : assert(count >= 0);

  final int count;

  @override
  int resolve(int laidOutCount) => count;

  @override
  bool operator ==(Object other) =>
      other is _ItemsExtent && other.count == count;

  @override
  int get hashCode => count.hashCode;

  @override
  String toString() => 'PrefetchExtent.items($count)';
}

final class _LayoutsExtent extends PrefetchExtent {
  const _LayoutsExtent(this.factor) : assert(factor >= 0);

  final double factor;

  @override
  int resolve(int laidOutCount) => (laidOutCount * factor).ceil();

  @override
  bool operator ==(Object other) =>
      other is _LayoutsExtent && other.factor == factor;

  @override
  int get hashCode => factor.hashCode;

  @override
  String toString() => 'PrefetchExtent.layouts($factor)';
}
