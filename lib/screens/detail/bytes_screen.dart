import 'package:flutter/cupertino.dart';

import '../../widgets/tool_bodies/bytes_body.dart';
import '../../widgets/tool_bodies/seed_source.dart';
import 'detail_scaffold.dart';

class BytesScreen extends StatelessWidget {
  const BytesScreen({super.key, this.initialInput});

  final String? initialInput;

  @override
  Widget build(BuildContext context) {
    return MqDetailScaffold(
      title: 'Bytes',
      subtitle: 'Byte array ↔ text (UTF-8). Brackets optional on decode.',
      child: BytesBody(
        initialInput: initialInput,
        seedSource: initialInput == null || initialInput!.isEmpty
            ? SeedSource.none
            : SeedSource.paste,
      ),
    );
  }
}
