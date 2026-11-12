# sliver_prefetch

Prefetch callbacks for Flutter slivers, modelled on UIKit's
[`UICollectionViewDataSourcePrefetching`](https://developer.apple.com/documentation/uikit/uicollectionviewdatasourceprefetching).
Learn which indices are about to scroll into view, and which no longer are,
for any `SliverList` or `SliverGrid`, whatever its layout.

Most Flutter pagination packages answer "the user reached the end, load the
next page", and own your list to do it. This one answers a different question:
*which children are about to be needed?* That suits data whose shape you
already know but whose contents arrive later: a list of ids hydrated in pages,
thumbnails to warm, videos to preload, rows that can be jumped into at any
offset.

## Install

```sh
flutter pub add sliver_prefetch
```

## Usage

```dart
class _GalleryState extends State<Gallery> {
  late final _prefetcher = SliverPrefetcher(
    ahead: const PrefetchExtent.layouts(1),   // one laid-out range ahead
    behind: const PrefetchExtent.items(6),    // a little behind, for turnarounds
    onPrefetch: (indices) => repository.load(indices),
    onCancelPrefetch: (indices) => repository.cancel(indices),
  );

  @override
  void dispose() {
    _prefetcher.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
        ),
        delegate: PrefetchingSliverChildBuilderDelegate(
          (context, index) => Tile(index),
          childCount: repository.count,
          prefetcher: _prefetcher,
        ),
      ),
    ],
  );
}
```

Have a delegate of your own? Mix in `SliverPrefetchingDelegateMixin` and
provide a `prefetcher` getter.

## How it works

`RenderSliverList` and `RenderSliverGrid` call
`SliverChildDelegate.didFinishLayout(firstIndex, lastIndex)` after every
layout with the range of children they built, cache extent included. The
delegate passes that range to the `SliverPrefetcher`, which:

1. infers the direction of travel from how the range moved;
2. computes the window: `ahead` past the leading edge, `behind` past the
   trailing one, clipped to `[0, childCount)`;
3. reports indices that entered the window to `onPrefetch`, nearest first,
   and indices that left it without being laid out to `onCancelPrefetch`;
4. does all of this after the frame, once per frame, because layout is no
   place to mark anything dirty.

Indices that scroll into view are retired silently, as on iOS. An index is
not reported twice while outstanding. Call `invalidate` to report particular
indices again (a fetch failed, say), or `reset` when the data behind the
indices changes.

## Options

| Option | Default | Meaning |
| --- | --- | --- |
| `ahead` | `PrefetchExtent.layouts(1)` | Look-ahead in the direction of travel |
| `behind` | `PrefetchExtent.none` | Look-ahead against it |
| `includeLaidOut` | `false` | Also report laid-out children, for cells that do not load their own data |
| `enabled` | `true` | Pause reporting; re-enabling reports the window afresh |

`PrefetchExtent.items(n)` is a fixed count. `PrefetchExtent.layouts(f)` is a
multiple of however many children are laid out, so it adapts to screen size,
item size and column count on its own.

## Caveats

- **Prefetching is a hint.** Callbacks can name indices that are already
  loaded. Make handlers idempotent.
- **Keep-alives widen the range.** The range comes from the sliver's element
  map, which also holds `AutomaticKeepAlive` children. A kept-alive child far
  off screen stretches the reported range to reach it.
- **One prefetcher per sliver.** It remembers one range.
- **Empty slivers.** With a `childCount` of 0 nothing is reported. With an
  unknown count and no children, Flutter reports `(0, 0)`, which reads as
  child 0 being laid out.

## Example

[`example/`](example/lib/main.dart) is a 1,000-cell grid over a repository
that takes 600 ms per page, with a switch to compare prefetching against
loading only what is on screen.

## License

BSD 3-Clause. See [LICENSE](LICENSE).
