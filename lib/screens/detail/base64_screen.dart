import 'package:flutter/cupertino.dart';

import '../../widgets/tool_bodies/base64_body.dart';
import '../../widgets/tool_bodies/seed_source.dart';
import 'detail_scaffold.dart';

class Base64Screen extends StatelessWidget {
  const Base64Screen({super.key, this.initialInput});

  final String? initialInput;

  @override
  Widget build(BuildContext context) {
    return MqDetailScaffold(
      title: 'Base64',
      subtitle: 'Encode/decode. Swap. URL-safe + strip-padding options.',
      child: Base64Body(
        initialInput: initialInput,
        seedSource: initialInput == null || initialInput!.isEmpty
            ? SeedSource.none
            : SeedSource.paste,
      ),
    );
  }
}
