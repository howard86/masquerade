import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/mq_metrics.dart';
import '../theme/mq_theme.dart';
import '../theme/mq_typography.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  static Future<void> push(BuildContext context) => Navigator.of(
    context,
  ).push(CupertinoPageRoute<void>(builder: (_) => const PrivacyPolicyScreen()));

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  late final Future<String> _policy = rootBundle.loadString('docs/privacy.md');

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: c.surface,
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
        previousPageTitle: 'Settings',
        middle: Text(
          'Privacy Policy',
          style: MqTextStyles.headline.copyWith(color: c.textPri),
        ),
      ),
      child: SafeArea(
        child: FutureBuilder<String>(
          future: _policy,
          builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Privacy policy could not be loaded.',
                  style: MqTextStyles.body.copyWith(color: c.textSec),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CupertinoActivityIndicator());
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(MqSpacing.lg),
              child: Text(
                snapshot.data!,
                style: MqTextStyles.body.copyWith(color: c.textPri),
              ),
            );
          },
        ),
      ),
    );
  }
}
