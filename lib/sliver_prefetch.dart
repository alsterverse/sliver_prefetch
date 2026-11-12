/// Prefetch callbacks for Flutter slivers, modelled on UIKit's
/// `UICollectionViewDataSourcePrefetching`.
///
/// Wrap a sliver's children in a [PrefetchingSliverChildBuilderDelegate] (or
/// mix [SliverPrefetchingDelegateMixin] into your own delegate) and hand it a
/// [SliverPrefetcher]. After every layout the prefetcher works out which
/// indices are about to scroll into view and reports them through
/// [SliverPrefetcher.onPrefetch], and reports the ones that stopped being
/// likely through [SliverPrefetcher.onCancelPrefetch].
library;

export 'src/prefetch_extent.dart';
export 'src/prefetch_window.dart';
export 'src/prefetching_delegate.dart';
export 'src/sliver_prefetcher.dart';
