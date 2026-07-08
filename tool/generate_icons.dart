// Icon generator (run with `flutter test test/gen_icon_test.dart`).
//
// Rasterizes assets/logo.svg into launcher-icon PNGs using the Flutter engine,
// so no external tool (ImageMagick / Inkscape) is needed. Writes:
//   assets/icon/app_icon.png             1024², white background + logo
//   assets/icon/app_icon_foreground.png  1024², transparent + smaller logo
// Then `dart run flutter_launcher_icons` consumes these.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _render({
  required ui.Picture logo,
  required ui.Size logoSize,
  required double target, // logo box size within the 1024 canvas
  required Color? background,
  required String path,
}) async {
  const canvasSize = 1024.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  if (background != null) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, canvasSize, canvasSize),
      Paint()..color = background,
    );
  }

  final scale = target / logoSize.longestSide;
  final w = logoSize.width * scale;
  final h = logoSize.height * scale;
  final dx = (canvasSize - w) / 2;
  final dy = (canvasSize - h) / 2;

  canvas.save();
  canvas.translate(dx, dy);
  canvas.scale(scale);
  canvas.drawPicture(logo);
  canvas.restore();

  final img = await recorder.endRecording().toImage(
        canvasSize.toInt(),
        canvasSize.toInt(),
      );
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('generate launcher icons from logo.svg', (tester) async {
    await tester.runAsync(() async {
      Directory('assets/icon').createSync(recursive: true);

      final rawSvg = File('assets/logo.svg').readAsStringSync();
      final info = await vg.loadPicture(SvgStringLoader(rawSvg), null);
      final logoSize = info.size;

      // Full icon: white background, logo at ~60% of the canvas.
      await _render(
        logo: info.picture,
        logoSize: logoSize,
        target: 620,
        background: Colors.white,
        path: 'assets/icon/app_icon.png',
      );

      // Adaptive foreground: transparent, logo smaller so it stays inside the
      // Android safe zone (central ~66%).
      await _render(
        logo: info.picture,
        logoSize: logoSize,
        target: 500,
        background: null,
        path: 'assets/icon/app_icon_foreground.png',
      );

      info.picture.dispose();
    });

    expect(File('assets/icon/app_icon.png').existsSync(), isTrue);
    expect(File('assets/icon/app_icon_foreground.png').existsSync(), isTrue);
  });
}
