// Records the README demo: the example gallery twice, side by side, with the
// look-ahead on and off, scrolled at the same speed.
//
// Run tool/record_demo.sh, which renders the frames with this test and
// encodes them to doc/demo.webp. Time is faked, so every run is identical.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliver_prefetch_example/main.dart';

const _fps = 30;
const _pane = Size(400, 700);
const _gap = 12.0;
const _pixelRatio = 2.0;
const _labelHeight = 36.0;

/// Scroll speed, in logical pixels per second: quick enough that loading
/// only what is on screen visibly falls behind.
const _speed = 1800.0;

Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'] ??
      // flutter_tester lives in <root>/bin/cache/artifacts/engine/<platform>/.
      File(Platform.resolvedExecutable)
          .parent
          .parent
          .parent
          .parent
          .parent
          .parent
          .path;
  final fonts = '$root/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final weight in ['Regular', 'Medium']) {
    final bytes = File('$fonts/Roboto-$weight.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: _labelHeight,
        child: Center(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      );
}

class _SideBySide extends StatelessWidget {
  const _SideBySide({required this.boundary});

  final GlobalKey boundary;

  @override
  Widget build(BuildContext context) {
    Widget pane(String label) => SizedBox(
          width: _pane.width,
          child: Column(
            children: [
              _Label(label),
              const SizedBox(height: 700, child: GalleryScreen()),
            ],
          ),
        );
    return RepaintBoundary(
      key: boundary,
      child: ColoredBox(
        color: const Color(0xFF0A0D10),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'Roboto',
              color: Color(0xFFE6E9EE),
              fontSize: 14,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                pane('With sliver_prefetch'),
                const SizedBox(width: _gap),
                pane('On-screen loading only'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('record demo frames', (tester) async {
    final out = Directory(
      Platform.environment['DEMO_FRAMES'] ?? 'build/demo_frames',
    )..createSync(recursive: true);
    for (final file in out.listSync()) {
      file.deleteSync();
    }

    await tester.runAsync(_loadRoboto);
    final size = Size(_pane.width * 2 + _gap, _pane.height + _labelHeight);
    tester.view
      ..physicalSize = size * _pixelRatio
      ..devicePixelRatio = _pixelRatio;
    addTearDown(tester.view.reset);

    final boundary = GlobalKey();
    await tester.pumpWidget(Center(child: _SideBySide(boundary: boundary)));

    // The right-hand gallery loads only what is on screen.
    await tester.tap(find.text('Look ahead: on').last);
    await tester.pump();

    final positions = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .map((s) => s.position)
        .toList();

    var frame = 0;
    Future<void> capture() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: _pixelRatio);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final name = '${frame++}'.padLeft(4, '0');
        File('${out.path}/$name.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    const step = Duration(milliseconds: 1000 ~/ _fps);
    Future<void> hold(double seconds) async {
      for (var i = 0; i < seconds * _fps; i++) {
        await tester.pump(step);
        await capture();
      }
    }

    Future<void> scroll(double seconds, double direction) async {
      for (var i = 0; i < seconds * _fps; i++) {
        for (final position in positions) {
          position.jumpTo(
            (position.pixels + direction * _speed / _fps)
                .clamp(0, position.maxScrollExtent),
          );
        }
        await tester.pump(step);
        await capture();
      }
    }

    await hold(1);
    await scroll(4, 1);
    await hold(1.2);

    // Let pending fetches settle so no timers outlive the test.
    await tester.pump(const Duration(seconds: 1));
  });
}
