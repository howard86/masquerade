import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/widgets/tool_bodies/base64_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

/// Base64 of a 1×1 transparent PNG (starts with the PNG magic 89 50 4E 47).
const String _png1x1 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=';

/// Three 1x1 red/green/blue frames, 100 ms each, looping forever.
const String _animatedGif =
    'R0lGODlhAQABAKEDAAAA//8AAAD/AP///yH/C05FVFNDQVBFMi4wAwEAAAAh+QQACgD/ACwAAAAAAQABAAACAkwBACH5BAAKAP8ALAAAAAABAAEAAAICVAEAIfkEAAoA/wAsAAAAAAEAAQAAAgJEAQA7';
const String _portraitJpeg =
    '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkICQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/2wBDAQMDAwQDBAgEBAgQCwkLEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBD/wAARCAGQAGQDAREAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAj/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFgEBAQEAAAAAAAAAAAAAAAAAAAUI/8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAwDAQACEQMRAD8AmREaDAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAf/2Q==';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> decode(
    WidgetTester tester,
    double width, {
    String input = _png1x1,
    double devicePixelRatio = 1,
  }) async {
    tester.view.devicePixelRatio = devicePixelRatio;
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpBodyAtWidth(tester, const Base64Body(), width);
    await tester.tap(find.text('Decode'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, input);
    await tester.pumpAndSettle(kDebouncePump);
  }

  testWidgets('Base64 — image preview + byte delta hidden at phone width', (
    WidgetTester tester,
  ) async {
    await decode(tester, 340);

    // Mobile parity: no image preview, no byte-delta readout.
    expect(find.byType(Image), findsNothing);
    expect(find.text('Byte delta'), findsNothing);
  });

  testWidgets('Base64 — image preview + byte delta visible at wide width', (
    WidgetTester tester,
  ) async {
    await decode(tester, 640);

    // PNG sniffed → preview renders, labelled, with a byte-delta readout.
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('PNG image'), findsOneWidget);
    expect(find.text('Byte delta'), findsOneWidget);
  });

  for (final double dpr in <double>[1, 2, 3]) {
    testWidgets('Base64 — preview decodes for DPR $dpr without upscaling', (
      WidgetTester tester,
    ) async {
      await decode(tester, 640, devicePixelRatio: dpr);

      final Image preview = tester.widget<Image>(find.byType(Image));
      final ResizeImage provider = preview.image as ResizeImage;
      expect(provider.policy, ResizeImagePolicy.fit);
      expect(provider.allowUpscaling, isFalse);
      expect(provider.height, 240 * dpr);
      expect(provider.imageProvider, isA<MemoryImage>());
    });
  }

  testWidgets(
    'Base64 — preview uses aspect-fit for portrait, landscape, and panoramas',
    (WidgetTester tester) async {
      await decode(tester, 640, devicePixelRatio: 2);
      final Image preview = tester.widget<Image>(find.byType(Image));
      final ResizeImage provider = preview.image as ResizeImage;
      expect(provider.policy, ResizeImagePolicy.fit);
      expect(provider.width, isNull);
      expect(provider.height, 480);
      expect(preview.fit, BoxFit.contain);
    },
  );

  testWidgets('Base64 — animated GIF remains renderable after its next frame', (
    WidgetTester tester,
  ) async {
    await decode(tester, 640, input: _animatedGif, devicePixelRatio: 2);
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Could not render image.'), findsNothing);
  });

  testWidgets('Base64 — JPEG preview uses the same bounded provider', (
    WidgetTester tester,
  ) async {
    await decode(tester, 640, input: _portraitJpeg, devicePixelRatio: 2);
    final Image preview = tester.widget<Image>(find.byType(Image));
    expect(preview.image, isA<ResizeImage>());
    expect(find.text('JPEG image'), findsOneWidget);
  });

  testWidgets('Base64 — corrupt image keeps the local render error', (
    WidgetTester tester,
  ) async {
    await decode(
      tester,
      640,
      input: base64Encode(const <int>[0x89, 0x50, 0x4E, 0x47]),
    );

    expect(find.text('Could not render image.'), findsOneWidget);
  });
}
