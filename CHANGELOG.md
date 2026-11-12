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
