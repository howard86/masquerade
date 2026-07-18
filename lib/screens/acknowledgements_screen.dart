import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../theme/mq_metrics.dart';
import '../theme/mq_theme.dart';
import '../theme/mq_typography.dart';
import '../widgets/mq/mq_surface.dart';

class AcknowledgementsScreen extends StatefulWidget {
  const AcknowledgementsScreen({super.key});

  static Future<void> push(BuildContext context) => Navigator.of(context).push(
    CupertinoPageRoute<void>(builder: (_) => const AcknowledgementsScreen()),
  );

  @override
  State<AcknowledgementsScreen> createState() => _AcknowledgementsScreenState();
}

class _AcknowledgementsScreenState extends State<AcknowledgementsScreen> {
  late final Future<List<LicenseEntry>> _licenses = LicenseRegistry.licenses
      .toList();

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
          'Acknowledgements',
          style: MqTextStyles.headline.copyWith(color: c.textPri),
        ),
      ),
      child: SafeArea(
        child: FutureBuilder<List<LicenseEntry>>(
          future: _licenses,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<LicenseEntry>> snapshot,
              ) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Acknowledgements could not be loaded.',
                      style: MqTextStyles.body.copyWith(color: c.textSec),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CupertinoActivityIndicator());
                }
                final List<LicenseEntry> licenses = snapshot.data!;
                if (licenses.isEmpty) {
                  return Center(
                    child: Text(
                      'No acknowledgements available.',
                      style: MqTextStyles.body.copyWith(color: c.textSec),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(MqSpacing.lg),
                  itemCount: licenses.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: MqSpacing.md),
                  itemBuilder: (_, int index) =>
                      _LicenseCard(entry: licenses[index]),
                );
              },
        ),
      ),
    );
  }
}

class _LicenseCard extends StatelessWidget {
  const _LicenseCard({required this.entry});

  final LicenseEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final List<String> packages = entry.packages.toSet().toList()..sort();
    return MqSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            packages.join(', '),
            style: MqTextStyles.headline.copyWith(color: c.textPri),
          ),
          const SizedBox(height: MqSpacing.sm),
          Text(
            entry.paragraphs.map((LicenseParagraph p) => p.text).join('\n\n'),
            style: MqTextStyles.footnote.copyWith(color: c.textSec),
          ),
        ],
      ),
    );
  }
}
