import 'package:flutter/cupertino.dart';

import '../../widgets/tool_bodies/number_base_body.dart';
import '../../widgets/tool_bodies/seed_source.dart';
import 'detail_scaffold.dart';

class NumberBaseScreen extends StatelessWidget {
  const NumberBaseScreen({super.key, this.initialInput});

  final String? initialInput;

  @override
  Widget build(BuildContext context) {
    return MqDetailScaffold(
      title: 'Number Base',
      subtitle: 'Auto-detect base. All forms shown live.',
      child: NumberBaseBody(
        initialInput: initialInput,
        seedSource: initialInput == null || initialInput!.isEmpty
            ? SeedSource.none
            : SeedSource.paste,
      ),
    );
  }
}
