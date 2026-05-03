import 'package:flutter/cupertino.dart';

import '../../widgets/tool_bodies/bps_body.dart';
import '../../widgets/tool_bodies/seed_source.dart';
import 'detail_scaffold.dart';

class BpsScreen extends StatelessWidget {
  const BpsScreen({super.key, this.initialInput});

  final String? initialInput;

  @override
  Widget build(BuildContext context) {
    return MqDetailScaffold(
      title: 'bps · % · decimal',
      subtitle: 'Auto-detect. All three shown. Reference-only.',
      child: BpsBody(
        initialInput: initialInput,
        seedSource: initialInput == null || initialInput!.isEmpty
            ? SeedSource.none
            : SeedSource.paste,
      ),
    );
  }
}
