import 'package:flutter/cupertino.dart';

import '../state/favorites_controller.dart';
import '../state/history_controller.dart';
import '../theme/mb_metrics.dart';
import '../theme/mb_theme.dart';
import '../theme/mb_typography.dart';
import '../utility_catalog.dart';
import '../widgets/mb/mb_chip.dart';
import '../widgets/mb/mb_icons.dart';
import '../widgets/mb/mb_search_bar.dart';
import '../widgets/mb/mb_section_header.dart';
import '../widgets/mb/mb_utility_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onSearchTapped});

  final VoidCallback onSearchTapped;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  void _open(BuildContext context, UtilityDescriptor u) {
    Navigator.of(
      context,
    ).push(CupertinoPageRoute<void>(builder: u.builder, title: u.name));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.mb;
    final c = tokens.colors;
    final HistoryController history = HistoryScope.of(context);
    final FavoritesController favorites = FavoritesScope.of(context);

    final Set<String> seen = <String>{};
    final List<UtilityDescriptor> recents = <UtilityDescriptor>[];
    for (final HistoryEntry e in history.entries.take(20)) {
      if (!seen.add(e.utilityId)) continue;
      final UtilityDescriptor? match = UtilityCatalog.all
          .where((UtilityDescriptor u) => u.id == e.utilityId)
          .firstOrNull;
      if (match != null) recents.add(match);
      if (recents.length >= 5) break;
    }

    final List<UtilityDescriptor> favs = UtilityCatalog.all
        .where((UtilityDescriptor u) => favorites.isFavorite(u.id))
        .toList();

    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            MBSpacing.lg,
            MBSpacing.sm,
            MBSpacing.lg,
            96,
          ),
          children: <Widget>[
            Text(
              'Magic Box',
              style: MBTextStyles.title1.copyWith(color: c.textPri),
            ),
            const SizedBox(height: 2),
            Row(
              children: <Widget>[
                Icon(MBIcons.lock, size: 11, color: c.success),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'On-device · nothing leaves your phone',
                    style: MBTextStyles.caption1.copyWith(color: c.textSec),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MBSpacing.md),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onSearchTapped,
              child: AbsorbPointer(
                child: MBSearchBar(controller: _searchController),
              ),
            ),
            const SizedBox(height: MBSpacing.md),
            if (recents.isNotEmpty) ...<Widget>[
              MBSectionHeader(
                label: 'Recents',
                trailing: MBChip(label: '${recents.length}', mono: true),
              ),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: recents.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: MBSpacing.sm),
                  itemBuilder: (_, int i) => SizedBox(
                    width: 168,
                    child: MBUtilityTile(
                      name: recents[i].name,
                      icon: recents[i].icon,
                      tint: recents[i].tint,
                      onTap: () => _open(context, recents[i]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: MBSpacing.md),
            ],
            if (favs.isNotEmpty) ...<Widget>[
              const MBSectionHeader(label: 'Favorites'),
              _UtilityGrid(items: favs, favorites: favorites, onTap: _open),
              const SizedBox(height: MBSpacing.md),
            ],
            for (final MBCategory cat in MBCategory.values) ...<Widget>[
              MBSectionHeader(
                label: cat.label,
                trailing: MBChip(
                  label: '${UtilityCatalog.byCategory(cat).length}',
                  mono: true,
                ),
              ),
              _UtilityGrid(
                items: UtilityCatalog.byCategory(cat),
                favorites: favorites,
                onTap: _open,
              ),
              const SizedBox(height: MBSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

class _UtilityGrid extends StatelessWidget {
  const _UtilityGrid({
    required this.items,
    required this.favorites,
    required this.onTap,
  });
  final List<UtilityDescriptor> items;
  final FavoritesController favorites;
  final void Function(BuildContext, UtilityDescriptor) onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 4.0,
      ),
      itemBuilder: (BuildContext context, int i) {
        final UtilityDescriptor u = items[i];
        return MBUtilityTile(
          name: u.name,
          icon: u.icon,
          tint: u.tint,
          favorite: favorites.isFavorite(u.id),
          onTap: () => onTap(context, u),
          onToggleFavorite: () => favorites.toggle(u.id),
        );
      },
    );
  }
}
