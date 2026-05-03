import 'package:flutter/cupertino.dart';

import '../../widgets/tool_bodies/json_body.dart';
import '../../widgets/tool_bodies/seed_source.dart';
import 'detail_scaffold.dart';

class JSONScreen extends StatelessWidget {
  const JSONScreen({super.key, this.initialInput});

  final String? initialInput;

  @override
  Widget build(BuildContext context) {
    return MqDetailScaffold(
      title: 'JSON',
      subtitle: 'Pretty / Minify / Tree. Errors point to line:column.',
      child: JSONBody(
        initialInput: initialInput,
        seedSource: initialInput == null || initialInput!.isEmpty
            ? SeedSource.none
            : SeedSource.paste,
      ),
    );
  }
}
