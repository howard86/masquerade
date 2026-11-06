import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/wallpaper_controller.dart';
import 'package:masquerade/state/window_content.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/desktop/desktop_icon_grid.dart';

double _lum(Color c) {
  double lin(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

double _contrast(Color a, Color b) {
  final double la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  testWidgets('icon labels and tints stay legible on every wallpaper', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final String label = UtilityCatalog.all.first.name;
    final List<Color> tints = <Color>[
      for (final UtilityDescriptor d in UtilityCatalog.all) d.tint,
      for (final SystemApp a in SystemApp.values) SystemWindow(a).tint,
    ];

    for (final MqWallpaperType type in MqWallpaperType.values) {
      for (final Brightness app in Brightness.values) {
        final MqTokens tokens = MqTokens(
          colors: app == Brightness.dark ? MqColors.dark() : MqColors.light(),
          brightness: app,
        );
        await tester.pumpWidget(
          CupertinoApp(
            home: WallpaperScope(
              controller: WallpaperController(initial: type),
              child: MqTheme(
                tokens: tokens,
                child: DesktopIconGrid(onOpen: (_) {}, onOpenSystem: (_) {}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final Color base = type.resolve(app).baseColor;
        final String where = '${type.name}/${app.name}';

        final Text text = tester.widget<Text>(find.text(label).first);
        final Color labelColor = text.style!.color!;
        final double lc = _contrast(labelColor, base);
        expect(lc, greaterThanOrEqualTo(4.5), reason: 'label on $where');

        // The grid re-themes to the wallpaper, so read the tokens it renders.
        final MqTokens inner = MqTheme.of(
          tester.element(find.text(label).first),
        );
        for (final Color tint in tints) {
          final Color fill = Color.alphaBlend(
            DesktopIconGrid.iconBacking(inner, tint),
            base,
          );
          final double tc = _contrast(tint, fill);
          expect(
            tc,
            greaterThanOrEqualTo(3.0),
            reason: 'tint $tint on backing, $where',
          );
        }
      }
    }
  });
}
