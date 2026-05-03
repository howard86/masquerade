import 'package:flutter/cupertino.dart';

import '../theme/mq_metrics.dart';
import '../theme/mq_theme.dart';
import '../theme/mq_typography.dart';
import '../utility_catalog.dart';
import '../widgets/mq/inline_tool_card.dart';
import '../widgets/mq/mq_icons.dart';
import '../widgets/mq/mq_search_bar.dart';
import '../widgets/tool_bodies/base64_body.dart';
import '../widgets/tool_bodies/bps_body.dart';
import '../widgets/tool_bodies/bytes_body.dart';
import '../widgets/tool_bodies/color_body.dart';
import '../widgets/tool_bodies/json_body.dart';
import '../widgets/tool_bodies/number_base_body.dart';
import '../widgets/tool_bodies/qr_code_body.dart';
import '../widgets/tool_bodies/seed_source.dart';
import '../widgets/tool_bodies/timestamp_body.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  String? _expandedToolId;
  String? _expandedSeed;
  SeedSource _expandedSeedSource = SeedSource.none;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<UtilityDescriptor> _results() {
    if (_query.trim().isEmpty) return UtilityCatalog.all;
    final String q = _query.trim().toLowerCase();
    return UtilityCatalog.all.where((UtilityDescriptor u) {
      if (u.name.toLowerCase().contains(q)) return true;
      if (u.id.toLowerCase().contains(q)) return true;
      return u.synonyms.any((String s) => s.contains(q));
    }).toList();
  }

  void _toggle(
    UtilityDescriptor u, {
    String? seed,
    SeedSource source = SeedSource.none,
  }) {
    setState(() {
      if (_expandedToolId == u.id) {
        _expandedToolId = null;
        _expandedSeed = null;
        _expandedSeedSource = SeedSource.none;
      } else {
        _expandedToolId = u.id;
        _expandedSeed = (seed != null && seed.isNotEmpty) ? seed : null;
        _expandedSeedSource = source;
      }
    });
  }

  Widget _buildBody(BuildContext context, UtilityDescriptor u) {
    final bool isThis = _expandedToolId == u.id;
    final String? seed = isThis ? _expandedSeed : null;
    final SeedSource source = isThis ? _expandedSeedSource : SeedSource.none;
    switch (u.id) {
      case 'number_base':
        return NumberBaseBody(initialInput: seed, seedSource: source);
      case 'timestamp':
        return TimestampBody(initialInput: seed, seedSource: source);
      case 'json':
        return JSONBody(initialInput: seed, seedSource: source);
      case 'base64':
        return Base64Body(initialInput: seed, seedSource: source);
      case 'color':
        return ColorBody(initialInput: seed, seedSource: source);
      case 'bps':
        return BpsBody(initialInput: seed, seedSource: source);
      case 'bytes':
        return BytesBody(initialInput: seed, seedSource: source);
      case 'qr_code':
        return QrCodeBody(
          initialInput: seed,
          seedSource: source,
          onSwitchTool: (UtilityDescriptor target, String input) =>
              _toggle(target, seed: input, source: SeedSource.paste),
        );
    }
    throw StateError('No body registered for tool id "${u.id}"');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final List<UtilityDescriptor> results = _results();
    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MqSpacing.lg,
                MqSpacing.md,
                MqSpacing.lg,
                MqSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Search',
                    style: MqTextStyles.largeTitle.copyWith(color: c.textPri),
                  ),
                  const SizedBox(height: MqSpacing.md),
                  MqSearchBar(
                    controller: _controller,
                    autofocus: true,
                    placeholder:
                        'Search utilities (try "epoch", "hex", "color")',
                    onChanged: (String v) {
                      setState(() {
                        _query = v;
                        // Collapse on query change so a previously-expanded
                        // card from outside the new result set goes away.
                        if (_expandedToolId != null &&
                            !UtilityCatalog.all.any(
                              (u) => u.id == _expandedToolId,
                            )) {
                          _expandedToolId = null;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty && _query.trim().isNotEmpty
                  ? _SearchEmptyState(query: _query.trim())
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        0,
                        0,
                        0,
                        MqLayout.tabBarClearance,
                      ),
                      itemCount: results.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: MqSpacing.sm),
                      itemBuilder: (BuildContext context, int i) {
                        final UtilityDescriptor u = results[i];
                        return InlineToolCard(
                          descriptor: u,
                          expanded: _expandedToolId == u.id,
                          onToggle: () => _toggle(u),
                          bodyBuilder: (BuildContext ctx) => _buildBody(ctx, u),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MqSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(MqIcons.search, size: 36, color: c.textTer),
            const SizedBox(height: MqSpacing.md),
            Text(
              'No matches',
              style: MqTextStyles.title3.copyWith(color: c.textPri),
            ),
            const SizedBox(height: MqSpacing.xs),
            Text(
              'Nothing matches "$query". Try a different keyword or check the synonyms list.',
              style: MqTextStyles.subhead.copyWith(color: c.textSec),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
