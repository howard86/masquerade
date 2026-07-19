import 'package:flutter/cupertino.dart';

import '../../state/library_controller.dart';
import '../../theme/mq_density.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../widgets/mq/mq_icons.dart';
import '../../widgets/mq/mq_search_bar.dart';
import '../../widgets/mq/mq_section_header.dart';
import '../../widgets/mq/tool_grid_card.dart';
import '../../widgets/tool_host.dart';
import '../history_screen.dart';
import '../library_screen.dart';
import '../settings_screen.dart';

/// The system (non-tool) destinations that share the sidebar with the tools.
enum _SystemPane { library, activity, settings }

/// Native split-view shell for genuinely tablet-sized viewports (iPad). A
/// permanent sidebar — search, the catalog grouped by category, and the
/// Library / Activity / Settings destinations — sits beside a detail pane that
/// hosts the current selection. Reuses the existing tool pipeline ([ToolHost])
/// and screens rather than reimplementing them. See `docs/adr/0004`.
///
/// Gated upstream on `!isWeb` (see `resolveShellLayout`), so the web mobile-
/// preview path is untouched. Cross-tool "Open in X" still pushes a full-screen
/// `ToolDetailRoute` on top, so the data-pipeline navigation keeps working.
class TabletShell extends StatefulWidget {
  const TabletShell({
    super.key,
    required this.libraryController,
    this.isWebOverride,
  });

  final LibraryController libraryController;

  /// See `MyApp.isWebOverride`. Forwarded to the embedded [SettingsScreen].
  final bool? isWebOverride;

  @override
  State<TabletShell> createState() => _TabletShellState();
}

class _TabletShellState extends State<TabletShell> {
  /// Categories that group the sidebar tool list, in reading order. `all` is a
  /// filter pseudo-category (see `UtilityCategory`) and never a group here.
  static const List<UtilityCategory> _groups = <UtilityCategory>[
    UtilityCategory.inspect,
    UtilityCategory.transform,
    UtilityCategory.generate,
    UtilityCategory.compareValidate,
  ];

  final TextEditingController _search = TextEditingController();
  String _query = '';

  // Exactly one of these is non-null when a destination is selected; both null
  // on first run, which shows the browse empty state.
  UtilityDescriptor? _tool;
  _SystemPane? _system;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _selectTool(UtilityDescriptor tool) => setState(() {
    _tool = tool;
    _system = null;
  });

  void _selectSystem(_SystemPane pane) => setState(() {
    _system = pane;
    _tool = null;
  });

  void _clearSelection() => setState(() {
    _tool = null;
    _system = null;
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Portrait fits a slightly narrower sidebar comfortably; landscape
          // earns the extra room. Size classes, not device checks.
          final bool landscape = constraints.maxWidth >= constraints.maxHeight;
          final double sidebarWidth = landscape ? 320 : 300;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: sidebarWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(
                      right: BorderSide(color: c.border, width: 0.5),
                    ),
                  ),
                  child: SafeArea(
                    right: false,
                    child: _Sidebar(
                      search: _search,
                      query: _query,
                      groups: _groups,
                      selectedTool: _tool,
                      selectedSystem: _system,
                      onQueryChanged: (String value) =>
                          setState(() => _query = value),
                      onSelectTool: _selectTool,
                      onSelectSystem: _selectSystem,
                    ),
                  ),
                ),
              ),
              Expanded(child: _detail(context)),
            ],
          );
        },
      ),
    );
  }

  Widget _detail(BuildContext context) {
    final UtilityDescriptor? tool = _tool;
    if (tool != null) return _ToolPane(descriptor: tool);
    return switch (_system) {
      _SystemPane.library => LibraryScope(
        controller: widget.libraryController,
        child: LibraryScreen(navigationBar: _paneNavBar(context, 'Library')),
      ),
      _SystemPane.activity => HistoryScreen(
        title: 'Activity',
        navigationBar: _paneNavBar(context, 'Activity'),
        onResume: _clearSelection,
      ),
      _SystemPane.settings => SettingsScreen(
        isWebOverride: widget.isWebOverride,
      ),
      null => _BrowseEmptyState(onSelectTool: _selectTool),
    };
  }
}

CupertinoNavigationBar _paneNavBar(BuildContext context, String title) {
  final c = context.mq.colors;
  return CupertinoNavigationBar(
    backgroundColor: c.surface,
    border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
    middle: Text(
      title,
      style: MqTextStyles.headline.copyWith(color: c.textPri),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.search,
    required this.query,
    required this.groups,
    required this.selectedTool,
    required this.selectedSystem,
    required this.onQueryChanged,
    required this.onSelectTool,
    required this.onSelectSystem,
  });

  final TextEditingController search;
  final String query;
  final List<UtilityCategory> groups;
  final UtilityDescriptor? selectedTool;
  final _SystemPane? selectedSystem;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<UtilityDescriptor> onSelectTool;
  final ValueChanged<_SystemPane> onSelectSystem;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MqSpacing.md,
            MqSpacing.sm,
            MqSpacing.md,
            MqSpacing.sm,
          ),
          child: MqSearchBar(
            controller: search,
            showShortcutHint: false,
            onChanged: onQueryChanged,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              MqSpacing.sm,
              MqSpacing.xs,
              MqSpacing.sm,
              MqSpacing.lg,
            ),
            children: <Widget>[
              ..._toolRows(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MqSpacing.sm,
                  MqSpacing.md,
                  MqSpacing.sm,
                  MqSpacing.sm,
                ),
                child: Container(height: 0.5, color: c.border),
              ),
              _SidebarRow(
                icon: MqIcons.list,
                iconColor: selectedSystem == _SystemPane.library
                    ? c.accent
                    : c.textSec,
                label: 'Library',
                selected: selectedSystem == _SystemPane.library,
                onTap: () => onSelectSystem(_SystemPane.library),
              ),
              _SidebarRow(
                icon: MqIcons.history,
                iconColor: selectedSystem == _SystemPane.activity
                    ? c.accent
                    : c.textSec,
                label: 'Activity',
                selected: selectedSystem == _SystemPane.activity,
                onTap: () => onSelectSystem(_SystemPane.activity),
              ),
              _SidebarRow(
                icon: MqIcons.setting,
                iconColor: selectedSystem == _SystemPane.settings
                    ? c.accent
                    : c.textSec,
                label: 'Settings',
                selected: selectedSystem == _SystemPane.settings,
                onTap: () => onSelectSystem(_SystemPane.settings),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _toolRows(BuildContext context) {
    final c = context.mq.colors;
    if (query.trim().isNotEmpty) {
      final List<UtilityDescriptor> results = UtilityCatalog.searchStable(
        query,
      );
      if (results.isEmpty) {
        return <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MqSpacing.sm,
              MqSpacing.md,
              MqSpacing.sm,
              MqSpacing.sm,
            ),
            child: Text(
              'No tools found',
              style: MqTextStyles.subhead.copyWith(color: c.textSec),
            ),
          ),
        ];
      }
      return <Widget>[for (final UtilityDescriptor tool in results) _row(tool)];
    }

    final List<Widget> rows = <Widget>[];
    for (final UtilityCategory category in groups) {
      final List<UtilityDescriptor> tools = UtilityCatalog.all
          .where((UtilityDescriptor u) => u.categories.first == category)
          .toList(growable: false);
      if (tools.isEmpty) continue;
      rows.add(
        MqSectionHeader(
          label: category.label,
          padding: const EdgeInsets.fromLTRB(
            MqSpacing.sm,
            MqSpacing.md,
            MqSpacing.sm,
            MqSpacing.xs,
          ),
        ),
      );
      for (final UtilityDescriptor tool in tools) {
        rows.add(_row(tool));
      }
    }
    return rows;
  }

  Widget _row(UtilityDescriptor tool) => _SidebarRow(
    icon: tool.icon,
    iconColor: tool.tint,
    label: tool.name,
    selected: selectedTool?.id == tool.id,
    onTap: () => onSelectTool(tool),
  );
}

/// A single tappable sidebar destination. Selection is the one accent voice:
/// an oxblood/gold tint fill and accent label (DESIGN.md's One Voice rule).
class _SidebarRow extends StatelessWidget {
  const _SidebarRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: MqSpacing.sm,
            vertical: MqSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? c.accentBg : null,
            borderRadius: BorderRadius.circular(MqRadius.sm),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: MqSpacing.md),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MqTextStyles.subhead.copyWith(
                    color: selected ? c.accent : c.textPri,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The detail pane for a selected tool: the shared [ToolHost] under a tool-name
/// nav bar, constrained to a readable column width and centered so single-
/// column tools don't stretch across a 13" canvas.
class _ToolPane extends StatelessWidget {
  const _ToolPane({required this.descriptor});

  final UtilityDescriptor descriptor;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      navigationBar: _paneNavBar(context, descriptor.name),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth < MqLayout.readableMaxWidth
              ? constraints.maxWidth
              : MqLayout.readableMaxWidth;
          return Center(
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: ToolHost(
                key: ValueKey<String>(descriptor.id),
                descriptor: descriptor,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// First-run teaching state: an editorial masthead over the full catalog as a
/// multi-column browse grid. Tapping a tile selects it in the detail pane.
class _BrowseEmptyState extends StatelessWidget {
  const _BrowseEmptyState({required this.onSelectTool});

  final ValueChanged<UtilityDescriptor> onSelectTool;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final MqDensity density = context.density;
    final double textScale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1, 2);
    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(MqSpacing.xl),
          children: <Widget>[
            Text(
              'Masquerade',
              style: MqTextStyles.largeTitle.copyWith(color: c.textPri),
            ),
            const SizedBox(height: MqSpacing.xs),
            Text(
              'Pick a tool to begin — inspect, convert, format, or generate, all on-device.',
              style: MqTextStyles.body.copyWith(color: c.textSec),
            ),
            const SizedBox(height: MqSpacing.xl),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: MqLayout.tileMaxExtent,
                mainAxisSpacing: density.cardGap,
                crossAxisSpacing: density.cardGap,
                childAspectRatio: density.cardAspectRatio / textScale,
              ),
              itemCount: UtilityCatalog.all.length,
              itemBuilder: (BuildContext context, int index) {
                final UtilityDescriptor tool = UtilityCatalog.all[index];
                return ToolGridCard(
                  descriptor: tool,
                  matched: false,
                  lastEntry: null,
                  showMetadata: true,
                  onTap: () => onSelectTool(tool),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
