import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:sliver_prefetch/sliver_prefetch.dart';

void main() => runApp(const ExampleApp());

const _background = Color(0xFF101418);
const _placeholder = Color(0xFF2A3038);
const _text = Color(0xFFE6E9EE);
const _accent = Color(0xFF7C9CFF);

/// Built on the widgets layer alone, so the example runs on every Flutter
/// the package supports and depends on nothing the package does not.
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => WidgetsApp(
    title: 'sliver_prefetch',
    color: _accent,
    textStyle: const TextStyle(color: _text, fontSize: 14),
    pageRouteBuilder: <T>(settings, builder) =>
        PageRouteBuilder<T>(pageBuilder: (context, _, _) => builder(context)),
    home: const GalleryScreen(),
  );
}

/// A data source whose shape is known up front but whose items arrive in
/// slow pages, like a list of ids hydrated from a server.
class SlowRepository extends ChangeNotifier {
  SlowRepository({this.count = 1000, this.pageSize = 12});

  final int count;
  final int pageSize;
  final Map<int, Color> _items = {};
  final Map<int, Timer> _pending = {};
  final _random = Random(1);

  int fetches = 0;
  int cancels = 0;

  Color? itemAt(int index) => _items[index];

  /// Fetches the pages covering [indices] that are neither loaded nor
  /// already on their way.
  void load(List<int> indices) {
    for (final index in indices) {
      final page = index ~/ pageSize;
      if (_items.containsKey(index) || _pending.containsKey(page)) continue;
      fetches++;
      _pending[page] = Timer(const Duration(milliseconds: 600), () {
        _pending.remove(page);
        for (var i = page * pageSize; i < (page + 1) * pageSize; i++) {
          _items[i] = Color(0xFF000000 | _random.nextInt(0xFFFFFF));
        }
        notifyListeners();
      });
    }
    notifyListeners();
  }

  /// Drops pages none of whose items are still wanted.
  void cancel(List<int> indices) {
    for (final page in indices.map((i) => i ~/ pageSize).toSet()) {
      final timer = _pending.remove(page);
      if (timer == null) continue;
      timer.cancel();
      cancels++;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    for (final timer in _pending.values) {
      timer.cancel();
    }
    super.dispose();
  }
}

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _repository = SlowRepository();
  bool _prefetching = true;

  // Owned by the state, not the delegate: delegates are rebuilt on every
  // build, while the prefetcher remembers what it has asked for.
  late final _prefetcher = SliverPrefetcher(
    ahead: const PrefetchExtent.layouts(1),
    behind: const PrefetchExtent.items(6),
    // Cells here do not load their own data, so the ones on screen are
    // reported too; otherwise a jump would land on cells nobody asked for.
    includeLaidOut: true,
    onPrefetch: _repository.load,
    onCancelPrefetch: _repository.cancel,
  );

  // Loads only what is on screen: what scrolling feels like without
  // prefetching, for comparison.
  late final _onScreenOnly = SliverPrefetcher(
    ahead: PrefetchExtent.none,
    includeLaidOut: true,
    onPrefetch: _repository.load,
  );

  @override
  void dispose() {
    _prefetcher.dispose();
    _onScreenOnly.dispose();
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _background,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: _repository,
          builder: (context, _) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pages fetched: ${_repository.fetches}   '
                        'cancelled: ${_repository.cancels}   '
                        'travel: ${_prefetcher.travel.name}',
                      ),
                    ),
                    _Toggle(
                      label: 'Look ahead',
                      value: _prefetching,
                      onChanged: (value) => setState(() {
                        _prefetching = value;
                        // The incoming prefetcher missed the layouts while it
                        // was out, so it reports the current window afresh.
                        (value ? _prefetcher : _onScreenOnly).reset();
                      }),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(4),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                            ),
                        delegate: PrefetchingSliverChildBuilderDelegate(
                          (context, index) => _Tile(
                            index: index,
                            color: _repository.itemAt(index),
                          ),
                          childCount: _repository.count,
                          prefetcher: _prefetching
                              ? _prefetcher
                              : _onScreenOnly,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: value ? _accent : _placeholder,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text('$label: ${value ? 'on' : 'off'}'),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.index, required this.color});

  final int index;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: color ?? _placeholder,
      alignment: Alignment.center,
      child: Text(
        color == null ? '…' : '$index',
        style: const TextStyle(color: _text, fontSize: 18),
      ),
    );
  }
}
