## 0.1.5

- Docs: a "Compared with" section in the README, setting the package
  against a larger `cacheExtent`, infinite_scroll_pagination and
  visibility_detector, with counts from a new benchmark,
  `example/tool/cache_extent_benchmark_test.dart`. No changes to the
  package's code.

## 0.1.4

- Fix: the window's edges no longer move against the direction of travel.
  `PrefetchExtent.layouts` follows the laid-out count, which rises and falls
  by a row as rows enter and leave one at a time, so the leading edge fell
  back a row, cancelled children needed a moment later and asked for them
  again on the next layout. The hold lifts when the direction changes, on
  `reset`, on re-enabling, when the child count changes and when a sliver
  comes back into view.
- Add `PrefetchWindow.bounds`, and a `previous` parameter to
  `PrefetchWindow.target`, for the range with its held edges.
- Example: the repository cancels a pending page only once none of its
  items are wanted, as its documentation said.
- Docs: an animated demo in the README and on pub.dev compares the example
  grid with and without the look-ahead. `example/tool/record_demo.sh`
  renders it.

## 0.1.3

- Supports Flutter 3.19 and newer (Dart 3.3), down from 3.41. No changes to
  the package's behaviour; CI now tests on 3.19.
- Docs: `ListView.custom` and `GridView.custom` take the prefetching delegate
  too; the README says so and tests pin it.

## 0.1.2

- Releases are now published from GitHub Actions through pub.dev's automated
  publishing, under the verified publisher alster.se. No changes to the
  package's code.

## 0.1.1

- Fix: a sliver that builds no children is no longer reported as having
  laid out child 0. Flutter reports both as `(0, 0)`; a fixed-extent list or
  a grid scrolled wholly past the viewport produced a spurious look-ahead
  from index 0, cancelled what it had asked for, and on coming back read its
  direction of travel backwards. The delegate now counts its mounted
  children to tell the two apart.
- Add `SliverPrefetcher.reportNoChildrenBuilt`, for delegates that report
  their own layouts.
- Docs: the README's caveats are now pinned by tests.

## 0.1.0

- Initial release: `SliverPrefetcher`, `PrefetchingSliverChildBuilderDelegate`,
  `SliverPrefetchingDelegateMixin`, `PrefetchExtent` and the pure
  `PrefetchWindow` calculation.
