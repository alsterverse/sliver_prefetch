import 'package:flutter/widgets.dart';

import 'sliver_prefetcher.dart';

/// Reports every layout of the sliver it belongs to to a [SliverPrefetcher].
///
/// Mix it into any [SliverChildDelegate]. `RenderSliverList` and
/// `RenderSliverGrid` call `didFinishLayout` after each layout pass with the
/// range of children they built, cache extent included, so this works with
/// any list or grid layout, custom grid delegates too.
///
/// A layout that built no children is reported as
/// [SliverPrefetcher.reportNoChildrenBuilt]. Flutter describes it as
/// `(0, 0)`, the same as one that built child 0 alone, so this mixin wraps
/// each child to know which it was. A fixed-extent list or a grid scrolled
/// wholly past the viewport produces one.
///
/// The reported range comes from the sliver's element map, which also holds
/// children kept alive with `AutomaticKeepAlive`. A kept-alive child far from
/// the viewport widens the range to reach it, so avoid keep-alives on slivers
/// you prefetch for.
mixin SliverPrefetchingDelegateMixin on SliverChildDelegate {
  /// The prefetcher this delegate reports to.
  SliverPrefetcher get prefetcher;

  @override
  Widget? build(BuildContext context, int index) {
    final child = super.build(context, index);
    if (child == null) return null;
    // Takes the child's key so the sliver's element map, which matches
    // children by the key of the widget at the top, still finds a child that
    // moved, and findChildIndexCallback keeps working.
    return _MountedChild(
      key: child.key,
      counter: _MountedChildren.of(prefetcher),
      child: child,
    );
  }

  @override
  void didFinishLayout(int firstIndex, int lastIndex) {
    super.didFinishLayout(firstIndex, lastIndex);
    if (_MountedChildren.of(prefetcher).count == 0) {
      prefetcher.reportNoChildrenBuilt();
      return;
    }
    prefetcher.reportLayout(
      firstIndex,
      lastIndex,
      childCount: estimatedChildCount,
    );
  }
}

/// How many of a sliver's children are in the tree, kept per prefetcher
/// because delegates are rebuilt freely while the prefetcher persists.
class _MountedChildren {
  static final Expando<_MountedChildren> _byPrefetcher = Expando(
    'sliver_prefetch mounted children',
  );

  static _MountedChildren of(SliverPrefetcher prefetcher) =>
      _byPrefetcher[prefetcher] ??= _MountedChildren();

  int count = 0;
}

class _MountedChild extends StatefulWidget {
  const _MountedChild({super.key, required this.counter, required this.child});

  final _MountedChildren counter;
  final Widget child;

  @override
  State<_MountedChild> createState() => _MountedChildState();
}

/// Counts itself in while it is in the tree. The sliver deactivates a child
/// synchronously when it collects it during layout, so the count is current by
/// the time `didFinishLayout` runs, while `dispose` would only come at the end
/// of the frame. Kept-alive children are never deactivated, which matches the
/// element map the reported range comes from.
class _MountedChildState extends State<_MountedChild> {
  @override
  void initState() {
    super.initState();
    widget.counter.count++;
  }

  @override
  void didUpdateWidget(_MountedChild oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.counter != widget.counter) {
      oldWidget.counter.count--;
      widget.counter.count++;
    }
  }

  @override
  void activate() {
    super.activate();
    widget.counter.count++;
  }

  @override
  void deactivate() {
    widget.counter.count--;
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
