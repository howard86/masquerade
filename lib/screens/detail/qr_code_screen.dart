import 'package:flutter/cupertino.dart';

import '../../widgets/tool_bodies/qr_code_body.dart';
import '../../widgets/tool_bodies/seed_source.dart';
import 'detail_scaffold.dart';

class QrCodeScreen extends StatelessWidget {
  const QrCodeScreen({super.key, this.initialInput});

  final String? initialInput;

  @override
  Widget build(BuildContext context) {
    return MqDetailScaffold(
      title: 'QR Code',
      subtitle: 'Generate QR from text · scan QR with camera.',
      child: QrCodeBody(
        initialInput: initialInput,
        seedSource: initialInput == null || initialInput!.isEmpty
            ? SeedSource.none
            : SeedSource.paste,
      ),
    );
  }
}
