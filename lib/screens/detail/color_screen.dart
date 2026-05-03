import 'package:flutter/cupertino.dart';

import '../../widgets/tool_bodies/color_body.dart';
import '../../widgets/tool_bodies/seed_source.dart';
import 'detail_scaffold.dart';

class ColorScreen extends StatelessWidget {
  const ColorScreen({super.key, this.initialInput});

  final String? initialInput;

  @override
  Widget build(BuildContext context) {
    return MqDetailScaffold(
      title: 'Color',
      subtitle: 'Hero swatch. HEX/RGB/HSL/OKLCH. WCAG contrast.',
      child: ColorBody(
        initialInput: initialInput,
        seedSource: initialInput == null || initialInput!.isEmpty
            ? SeedSource.none
            : SeedSource.paste,
      ),
    );
  }
}
