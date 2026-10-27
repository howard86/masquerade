import 'package:flutter/cupertino.dart';

import '../state/history_controller.dart';
import '../state/library_controller.dart';
import '../theme/mq_density.dart';
import '../theme/mq_metrics.dart';
import '../theme/mq_theme.dart';
import '../theme/mq_typography.dart';
import '../utility_catalog.dart';
import '../widgets/mq/mq_chip.dart';
import '../widgets/mq/mq_search_bar.dart';
import '../widgets/mq/section_rule.dart';
import '../widgets/mq/tool_grid_card.dart';
import 'detail/tool_detail_route.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, this.navigationBar});

  final ObstructingPreferredSizeWidget? navigationBar;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _search = TextEditingController();
  UtilityCategory _category = UtilityCategory.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<HistoryEntry>? _recentsEntries;
  Duration? _recentsRetention;
  (List<UtilityDescriptor>, Map<String, HistoryEntry>) _recentsResult = (
    const <UtilityDescriptor>[],
    const <String, HistoryEntry>{},
  );

  /// Latest entry per tool, recomputed only when the controller's entries or
  /// retention change.
  (List<UtilityDescriptor>, Map<String, HistoryEntry>) _recentsFor(
    HistoryController history,
  ) {
    final List<HistoryEntry> entries = history.entries;
    if (identical(_recentsEntries, entries) &&
        _recentsRetention == history.retention) {
      return _recentsResult;
    }
    final Map<String, HistoryEntry> recentEntries = <String, HistoryEntry>{};
    if (history.retention != Duration.zero) {
      for (final HistoryEntry entry in entries) {
        recentEntries.putIfAbsent(entry.utilityId, () => entry);
      }
    }
    _recentsEntries = entries;
    _recentsRetention = history.retention;
    return _recentsResult = (
      <UtilityDescriptor>[
        for (final String id in recentEntries.keys)
          if (UtilityCatalog.byIdOrNull(id) case final UtilityDescriptor tool)
            tool,
      ],
      recentEntries,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final LibraryController library = LibraryScope.of(context);
    final HistoryController history = HistoryScope.read(context);
    final String query = _search.text.trim();
    final List<UtilityDescriptor> mainTools = query.isEmpty
        ? UtilityCatalog.inCategory(_category)
        : UtilityCatalog.searchStable(query);
    final List<UtilityDescriptor> favorites = UtilityCatalog.all
        .where((UtilityDescriptor u) => library.isFavorite(u.id))
        .toList(growable: false);

    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      navigationBar: widget.navigationBar,
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
            MqSearchBar(
              controller: _search,
              showShortcutHint: false,
              onChanged: (_) => setState(() {}),
            ),
            if (query.isEmpty) ...<Widget>[
              const SizedBox(height: MqSpacing.md),
              Wrap(
                spacing: MqSpacing.sm,
                runSpacing: MqSpacing.sm,
                children: <Widget>[
                  for (final UtilityCategory category in UtilityCategory.values)
                    MqChip(
                      label: category.label,
                      mono: false,
                      selected: _category == category,
                      onTap: () => setState(() => _category = category),
                    ),
                ],
              ),
            ],
            if (query.isEmpty && favorites.isNotEmpty) ...<Widget>[
              const SectionRule(label: 'Favorites'),
              _grid(context, favorites, library),
            ],
            if (query.isEmpty)
              // Only this section follows history writes; the rest of the
              // screen reads the controller without subscribing.
              ListenableBuilder(
                listenable: history,
                builder: (BuildContext context, _) {
                  final (
                    List<UtilityDescriptor> recents,
                    Map<String, HistoryEntry> entries,
                  ) = _recentsFor(
                    history,
                  );
                  if (recents.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const SectionRule(label: 'Recently used'),
                      _grid(context, recents, library, entries: entries),
                    ],
                  );
                },
              ),
            SectionRule(
              label: query.isEmpty ? _category.label : 'Search results',
            ),
            if (mainTools.isEmpty)
              Text(
                'No tools found',
                textAlign: TextAlign.center,
                style: MqTextStyles.body.copyWith(color: c.textSec),
              )
            else
              _grid(context, mainTools, library),
          ],
        ),
      ),
    );
  }

  Widget _grid(
    BuildContext context,
    List<UtilityDescriptor> tools,
    LibraryController library, {
    Map<String, HistoryEntry> entries = const <String, HistoryEntry>{},
  }) {
    final MqDensity density = context.density;
    final double textScale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1, 2);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 560,
        mainAxisSpacing: density.cardGap,
        crossAxisSpacing: density.cardGap,
        mainAxisExtent: 120 + (80 * (textScale - 1)),
      ),
      itemCount: tools.length,
      itemBuilder: (BuildContext context, int index) {
        final UtilityDescriptor tool = tools[index];
        final HistoryEntry? entry = entries[tool.id];
        return ToolGridCard(
          descriptor: tool,
          matched: false,
          lastEntry: entry,
          favorite: library.isFavorite(tool.id),
          onToggleFavorite: () => library.toggleFavorite(tool.id),
          showMetadata: true,
          onTap: () => ToolDetailRoute.push(context, tool, seed: entry?.input),
        );
      },
    );
  }
}
