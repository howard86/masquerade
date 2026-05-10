import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../state/history_controller.dart';
import '../theme/mq_density.dart';
import '../theme/mq_metrics.dart';
import '../theme/mq_theme.dart';
import '../utility_catalog.dart';
import '../utils/copy_util.dart';
import '../widgets/mq/compact_paste_bar.dart';
import '../widgets/mq/section_rule.dart';
import '../widgets/mq/tool_grid_card.dart';
import 'detail/qr_scanner_route.dart';
import 'detail/tool_detail_route.dart';

/// Home tab — compact paste bar (two-stage hero), hairline section rule, and
/// a 2-column tool grid sorted matched → recently-used → idle. Tapping a card
/// pushes a [ToolDetailRoute] seeded with the hero text.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _hero = TextEditingController();
  final FocusNode _heroFocus = FocusNode();
  Timer? _debounce;
  List<UtilityDescriptor> _matches = const <UtilityDescriptor>[];

  @override
  void initState() {
    super.initState();
    _hero.addListener(_onHeroChange);
    _heroFocus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _hero.removeListener(_onHeroChange);
    _heroFocus.removeListener(_onFocusChange);
    _hero.dispose();
    _heroFocus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  void _onHeroChange() {
    if (!mounted) return;
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _recomputeMatches);
  }

  void _recomputeMatches() {
    if (!mounted) return;
    final List<UtilityDescriptor> next = UtilityCatalog.detectAll(_hero.text);
    if (listEquals(next, _matches)) return;
    setState(() => _matches = next);
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = data?.text;
    if (text == null || text.isEmpty) return;
    _hero.text = text;
    _recomputeMatches();
  }

  void _clear() {
    _debounce?.cancel();
    _hero.clear();
    setState(() => _matches = const <UtilityDescriptor>[]);
  }

  Future<void> _scan() async {
    final String? result = await pushQrScanner(context);
    if (!mounted || result == null || result.isEmpty) return;
    _hero.text = result;
    _recomputeMatches();
  }

  void _open(UtilityDescriptor u) {
    final String text = _hero.text;
    ToolDetailRoute.push(context, u, seed: text.isNotEmpty ? text : null);
  }

  void _longPressCopy(BuildContext ctx, HistoryEntry entry) {
    if (entry.sensitive) return;
    HapticFeedback.mediumImpact();
    CopyToClipboardUtil.copyToClipboard(ctx, entry.output);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final HistoryController history = HistoryScope.of(context);
    final bool retentionOff = history.retention == Duration.zero;

    final Map<String, HistoryEntry> lastByTool = <String, HistoryEntry>{};
    final List<String> recentIds = <String>[];
    if (!retentionOff) {
      for (final HistoryEntry e in history.entries) {
        if (!lastByTool.containsKey(e.utilityId)) {
          lastByTool[e.utilityId] = e;
          recentIds.add(e.utilityId);
        }
      }
    }

    final Set<String> matchedIds = _matches
        .map((UtilityDescriptor u) => u.id)
        .toSet();
    final List<UtilityDescriptor> sorted = _sortCatalog(matchedIds, recentIds);
    final MqDensity d = context.density;

    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            MqSpacing.lg,
            MqSpacing.md,
            MqSpacing.lg,
            MqLayout.tabBarClearance,
          ),
          children: <Widget>[
            CompactPasteBar(
              controller: _hero,
              focusNode: _heroFocus,
              onPaste: _paste,
              onClear: _clear,
              onScan: _scan,
            ),
            const SectionRule(),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: d.cardGap,
                crossAxisSpacing: d.cardGap,
                childAspectRatio: d.isCompact ? 1.9 : 1.6,
              ),
              itemCount: sorted.length,
              itemBuilder: (BuildContext _, int i) {
                final UtilityDescriptor u = sorted[i];
                final HistoryEntry? entry = lastByTool[u.id];
                return ToolGridCard(
                  descriptor: u,
                  matched: matchedIds.contains(u.id),
                  lastEntry: entry,
                  onTap: () => _open(u),
                  onLongPress: entry == null
                      ? null
                      : () => _longPressCopy(context, entry),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Sort priority: matched (catalog order) → recently-used (recency order)
  /// → remainder (catalog order).
  List<UtilityDescriptor> _sortCatalog(
    Set<String> matchedIds,
    List<String> recentIds,
  ) {
    final List<UtilityDescriptor> out = <UtilityDescriptor>[];
    final Set<String> placed = <String>{};
    for (final UtilityDescriptor u in UtilityCatalog.all) {
      if (matchedIds.contains(u.id)) {
        out.add(u);
        placed.add(u.id);
      }
    }
    for (final String id in recentIds) {
      if (placed.contains(id)) continue;
      final UtilityDescriptor? u = UtilityCatalog.all
          .where((UtilityDescriptor d) => d.id == id)
          .firstOrNull;
      if (u == null) continue;
      out.add(u);
      placed.add(u.id);
    }
    for (final UtilityDescriptor u in UtilityCatalog.all) {
      if (!placed.contains(u.id)) out.add(u);
    }
    return out;
  }
}
