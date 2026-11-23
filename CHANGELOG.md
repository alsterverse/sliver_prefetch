## 0.1.4

- Docs: an animated demo in the README and on pub.dev compares the example
  grid with and without the look-ahead. `example/tool/record_demo.sh`
  renders it. No changes to the package's code.

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
