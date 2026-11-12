/// @docImport 'prefetching_delegate.dart';
library;

import 'package:flutter/scheduler.dart';

import 'prefetch_extent.dart';
import 'prefetch_window.dart';

/// Receives indices from a [SliverPrefetcher], in the order they matter.
typedef PrefetchCallback = void Function(List<int> indices);

/// Turns the layouts a sliver reports into prefetch and cancel callbacks, the
/// way `UICollectionViewDataSourcePrefetching` does for a collection view.
///
/// Create one per sliver and keep it for the sliver's lifetime, typically in a
/// `State`, then hand it to a [PrefetchingSliverChildBuilderDelegate] (or any
/// delegate using [SliverPrefetchingDelegateMixin]). Delegates are rebuilt
/// freely; the prefetcher is what remembers what has been asked for.
///
/// The sliver calls [reportLayout] during layout, where nothing may be marked
/// dirty, so the callbacks run after the frame instead. A burst of layouts in
/// one frame produces a single round of callbacks.
///
/// Prefetching is a hint, as on iOS. Callbacks may name an index that is
/// already loaded or that is being loaded for another reason, so make the
/// handlers idempotent. An index is not reported again while it is
/// outstanding; call [invalidate] or [reset] to have it reported again, for
/// instance after its fetch failed or the data set was replaced.
class SliverPrefetcher {
  /// Creates a prefetcher.
  ///
  /// By default it looks one layout's worth of children ahead in the
  /// direction of travel and nothing behind.
  SliverPrefetcher({
    this.ahead = const PrefetchExtent.layouts(1),
    this.behind = PrefetchExtent.none,
    this.includeLaidOut = false,
    this.onPrefetch,
    this.onCancelPrefetch,
    bool enabled = true,
    // A private field cannot back a public named parameter by itself.
    // ignore: prefer_initializing_formals
  }) : _enabled = enabled;

  /// How far past the laid-out children to look in the direction of travel.
  final PrefetchExtent ahead;

  /// How far past the laid-out children to look against the direction of
  /// travel, for a user who turns around.
  final PrefetchExtent behind;

  /// Whether laid-out children are reported as well.
  ///
  /// On iOS the data source loads a cell's data when the cell is configured,
  /// so prefetching only ever names cells that are not on screen yet. Turn
  /// this on when cells do not fetch their own data, so a jump that lands on
  /// children nobody prefetched still gets them loaded.
  final bool includeLaidOut;

  /// Called with indices that are about to be needed.
  final PrefetchCallback? onPrefetch;

  /// Called with indices reported to [onPrefetch] that are no longer about to
  /// be needed and were never laid out. Cancelling is optional.
  final PrefetchCallback? onCancelPrefetch;

  bool _enabled;
  bool _disposed = false;
  bool _flushScheduled = false;
  IndexRange? _laidOut;
  int? _childCount;
  ScrollTravel _travel = ScrollTravel.forward;
  Set<int> _outstanding = const {};

  /// Whether the prefetcher reports anything.
  ///
  /// Turning it off forgets what was outstanding without cancelling it.
  /// Turning it back on reports the current window afresh.
  bool get enabled => _enabled;
  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    _outstanding = const {};
    if (value) _scheduleFlush();
  }

  /// The children the sliver laid out last, if it has laid out at all.
  IndexRange? get laidOut => _laidOut;

  /// The direction the laid-out children were last seen moving.
  ScrollTravel get travel => _travel;

  /// The indices reported to [onPrefetch] and not yet cancelled or retired.
  Set<int> get outstanding => _outstanding;

  /// Records a layout. Called by the delegate from
  /// `SliverChildDelegate.didFinishLayout`, whose indices are inclusive.
  void reportLayout(int firstIndex, int lastIndex, {int? childCount}) {
    if (_disposed) return;
    final range = childCount == 0
        ? const IndexRange(0, 0)
        : IndexRange.laidOut(firstIndex, lastIndex);
    final previous = _laidOut;
    if (range == previous && childCount == _childCount) return;

    if (previous != null) {
      // Compared by midpoint so a range that grows on one side while it
      // shrinks on the other, as on a resize, still reads one way.
      final delta = (range.start + range.end) - (previous.start + previous.end);
      if (delta > 0) _travel = ScrollTravel.forward;
      if (delta < 0) _travel = ScrollTravel.backward;
    }
    _laidOut = range;
    _childCount = childCount;
    _scheduleFlush();
  }

  /// Forgets that [indices] were reported, so they are reported again if they
  /// are still in the window.
  void invalidate(Iterable<int> indices) {
    if (_disposed) return;
    _outstanding = _outstanding.difference(indices.toSet());
    _scheduleFlush();
  }

  /// Forgets everything that was reported, so the whole current window is
  /// reported again. Use it when the data behind the indices changes.
  void reset() {
    if (_disposed) return;
    _outstanding = const {};
    _scheduleFlush();
  }

  /// Stops all further callbacks.
  void dispose() {
    _disposed = true;
  }

  void _scheduleFlush() {
    if (_flushScheduled || !_enabled) return;
    _flushScheduled = true;
    final binding = SchedulerBinding.instance;
    binding.addPostFrameCallback(
      (_) => _flush(),
      debugLabel: 'SliverPrefetcher',
    );
    // A no-op mid-frame; called from outside one, as [reset] can be, it makes
    // sure there is a frame for the callback to follow.
    binding.ensureVisualUpdate();
  }

  void _flush() {
    _flushScheduled = false;
    final laidOut = _laidOut;
    if (_disposed || !_enabled || laidOut == null) return;

    final target = PrefetchWindow.target(
      laidOut: laidOut,
      childCount: _childCount,
      travel: _travel,
      ahead: ahead,
      behind: behind,
      includeLaidOut: includeLaidOut,
    );
    final update = PrefetchWindow.diff(
      outstanding: _outstanding,
      target: target,
      laidOut: laidOut,
      travel: _travel,
    );
    _outstanding = update.outstanding;

    if (update.cancel.isNotEmpty) onCancelPrefetch?.call(update.cancel);
    if (update.prefetch.isNotEmpty) onPrefetch?.call(update.prefetch);
  }
}
