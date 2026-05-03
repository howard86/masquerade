import 'package:flutter/cupertino.dart';

import '../../widgets/tool_bodies/seed_source.dart';
import '../../widgets/tool_bodies/timestamp_body.dart';
import 'detail_scaffold.dart';

class TimestampScreen extends StatelessWidget {
  const TimestampScreen({super.key, this.initialInput});

  final String? initialInput;

  @override
  Widget build(BuildContext context) {
    return MqDetailScaffold(
      title: 'Timestamp',
      subtitle:
          'Auto-detect ms vs s. Local TZ first; UTC + ISO + relative below.',
      child: TimestampBody(
        initialInput: initialInput,
        seedSource: initialInput == null || initialInput!.isEmpty
            ? SeedSource.none
            : SeedSource.paste,
      ),
    );
  }
}
