import 'package:flutter/widgets.dart';

import '../../theme/mq_theme.dart';
import 'mq_monogram.dart';
import 'mq_wordmark.dart';

/// Dart-side splash that mirrors `assets/brand/splash-{light,dark}.svg`.
/// Rendered for one breath after engine init, then crossfaded into the
/// app shell. Composition: framed `[ M. ]` monogram above the
/// `Masquerade` wordmark on a flat brand-bg fill.
class MqSplashScreen extends StatelessWidget {
  const MqSplashScreen({super.key});

  static const double _monogramSize = 168;
  static const double _wordmarkSize = 40;
  static const double _gap = 28;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return ColoredBox(
      color: c.bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const MqMonogram(size: _monogramSize),
            const SizedBox(height: _gap),
            MqWordmark(size: _wordmarkSize),
          ],
        ),
      ),
    );
  }
}
