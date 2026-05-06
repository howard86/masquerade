import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../state/history_controller.dart';
import '../theme/mq_metrics.dart';
import '../theme/mq_theme.dart';
import '../theme/mq_typography.dart';
import '../utility_catalog.dart';
import '../utils/copy_util.dart';
import '../widgets/mq/inline_tool_card.dart';
import '../widgets/mq/mq_button.dart';
import '../widgets/mq/mq_chip.dart';
import '../widgets/mq/mq_icons.dart';
import '../widgets/mq/mq_input.dart';
import '../widgets/mq/mq_recents_row.dart';
import '../widgets/mq/mq_section_header.dart';
import '../widgets/tool_bodies/seed_source.dart';
import 'detail/qr_scanner_route.dart';

/// Home tab — hero paste card on top, then (when hero detects something) a
/// suggestion row + auto-expand of the single best match, otherwise the
/// recents row + grid of all tool chips. Selecting a chip unfurls its body
/// inline; the rest of the grid hides until the user collapses.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _heroController = TextEditingController();
  Timer? _debounce;
  List<UtilityDescriptor> _matches = const <UtilityDescriptor>[];

  UtilityDescriptor? _expanded;
  String? _expandedSeed;
  SeedSource _expandedSeedSource = SeedSource.none;

  /// Set the moment the user takes a manual expansion action (chip tap,
  /// header tap, recents tap, cross-tool switch). Disables auto-expand for
  /// the rest of the session, until the hero is cleared. Prevents the
  /// auto-rule from snapping the user to a different tool after they made
  /// an explicit pick.
  bool _userOverrodeAuto = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _heroController.dispose();
    super.dispose();
  }

  void _onHeroChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _recomputeMatches);
  }

  void _recomputeMatches() {
    if (!mounted) return;
    final String heroText = _heroController.text;
    final List<UtilityDescriptor> next = UtilityCatalog.detectAll(heroText);
    final bool sameMatches = listEquals(next, _matches);

    final bool wantAutoExpand =
        !_userOverrodeAuto && next.length == 1 && _expanded != next.single;
    final bool wantReseed =
        _expanded != null &&
        next.contains(_expanded) &&
        heroText.isNotEmpty &&
        heroText != _expandedSeed;

    if (sameMatches && !wantAutoExpand && !wantReseed) return;

    setState(() {
      _matches = next;
      if (wantAutoExpand) {
        _expanded = next.single;
        _expandedSeed = heroText.isNotEmpty ? heroText : null;
        _expandedSeedSource = SeedSource.paste;
      } else if (wantReseed) {
        _expandedSeed = heroText;
        _expandedSeedSource = SeedSource.paste;
      }
    });
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = data?.text;
    if (text == null || text.isEmpty) return;
    _heroController.text = text;
    _recomputeMatches();
  }

  void _clear() {
    _debounce?.cancel();
    _heroController.clear();
    setState(() {
      _matches = const <UtilityDescriptor>[];
      _expanded = null;
      _expandedSeed = null;
      _expandedSeedSource = SeedSource.none;
      _userOverrodeAuto = false;
    });
  }

  Future<void> _scanToHero() async {
    final String? result = await pushQrScanner(context);
    if (!mounted || result == null || result.isEmpty) return;
    _heroController.text = result;
    _recomputeMatches();
  }

  /// Toggles [u] open or closed. Always counts as a manual override.
  void _toggle(UtilityDescriptor u) {
    setState(() {
      _userOverrodeAuto = true;
      if (_expanded == u) {
        _expanded = null;
        _expandedSeed = null;
        _expandedSeedSource = SeedSource.none;
      } else {
        _expanded = u;
        _expandedSeed = null;
        _expandedSeedSource = SeedSource.none;
      }
    });
  }

  /// Opens [u] from a hero-detection chip; carries the hero text as seed.
  void _openFromChip(UtilityDescriptor u) {
    setState(() {
      _userOverrodeAuto = true;
      _expanded = u;
      final String hero = _heroController.text;
      _expandedSeed = hero.isNotEmpty ? hero : null;
      _expandedSeedSource = hero.isNotEmpty
          ? SeedSource.paste
          : SeedSource.none;
    });
  }

  /// Cross-tool pipe: a body fires this to expand [target] seeded with
  /// [input]. Counts as a manual override.
  void _switchTool(UtilityDescriptor target, String input) {
    setState(() {
      _userOverrodeAuto = true;
      _expanded = target;
      _expandedSeed = input.isNotEmpty ? input : null;
      _expandedSeedSource = input.isNotEmpty
          ? SeedSource.paste
          : SeedSource.none;
    });
  }

  Widget _buildBody(BuildContext context, UtilityDescriptor u) {
    final bool isThis = _expanded == u;
    return u.builder(
      context,
      initialInput: isThis ? _expandedSeed : null,
      seedSource: isThis ? _expandedSeedSource : SeedSource.none,
      onSwitchTool: _switchTool,
    );
  }

  Key? _bodyKeyFor(UtilityDescriptor u) {
    if (_expanded != u) return null;
    // Seed is the only thing that drives a body remount; descriptor identity
    // is already pinned by the surrounding `if (_expanded != null)` branch
    // and SeedSource doesn't affect parse output.
    return ValueKey<String>(_expandedSeed ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final bool hasInput = _heroController.text.trim().isNotEmpty;

    final HistoryController history = HistoryScope.of(context);
    final bool retentionOff = history.retention == Duration.zero;
    final Map<String, HistoryEntry> lastByTool = <String, HistoryEntry>{};
    if (!retentionOff) {
      for (final HistoryEntry e in history.entries) {
        lastByTool.putIfAbsent(e.utilityId, () => e);
      }
    }
    final List<UtilityDescriptor> recents = <UtilityDescriptor>[];
    for (final String id in lastByTool.keys) {
      // Tolerate stale ids from removed tools.
      final UtilityDescriptor? u = UtilityCatalog.all
          .where((UtilityDescriptor d) => d.id == id)
          .firstOrNull;
      if (u != null) recents.add(u);
      if (recents.length >= 5) break;
    }

    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            MqSpacing.lg,
            MqSpacing.sm,
            MqSpacing.lg,
            MqLayout.tabBarClearance,
          ),
          children: <Widget>[
            Text(
              'Masquerade',
              style: MqTextStyles.title1.copyWith(color: c.textPri),
            ),
            const SizedBox(height: 2),
            Row(
              children: <Widget>[
                Icon(MqIcons.lock, size: 11, color: c.success),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'On-device · nothing leaves your phone',
                    style: MqTextStyles.caption1.copyWith(color: c.textSec),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MqSpacing.lg),
            _HeroPasteCard(
              controller: _heroController,
              onChanged: _onHeroChanged,
              onPaste: _paste,
              onClear: hasInput ? _clear : null,
              onScan: _scanToHero,
            ),
            if (_matches.isNotEmpty) ...<Widget>[
              const SizedBox(height: MqSpacing.md),
              _SuggestionRow(
                matches: _matches,
                expanded: _expanded,
                onTap: _openFromChip,
              ),
            ],
            if (_expanded == null && recents.isNotEmpty) ...<Widget>[
              const SizedBox(height: MqSpacing.lg),
              MqRecentsRow(
                recents: recents,
                expanded: _expanded,
                onTap: _openFromChip,
              ),
            ],
            const SizedBox(height: MqSpacing.lg),
            const MqSectionHeader(label: 'All tools'),
            const SizedBox(height: MqSpacing.sm),
            if (_expanded != null)
              InlineToolCard(
                descriptor: _expanded!,
                expanded: true,
                onToggle: () => _toggle(_expanded!),
                bodyKey: _bodyKeyFor(_expanded!),
                bodyBuilder: (BuildContext ctx) => _buildBody(ctx, _expanded!),
              )
            else
              Wrap(
                spacing: MqSpacing.sm,
                runSpacing: MqSpacing.sm,
                children: <Widget>[
                  for (final UtilityDescriptor u in UtilityCatalog.all)
                    _GridChipTile(
                      descriptor: u,
                      lastEntry: lastByTool[u.id],
                      onTap: () => _toggle(u),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _GridChipTile extends StatelessWidget {
  const _GridChipTile({
    required this.descriptor,
    required this.lastEntry,
    required this.onTap,
  });

  final UtilityDescriptor descriptor;
  final HistoryEntry? lastEntry;
  final VoidCallback onTap;

  static const int _previewMax = 24;

  static String? _truncate(String? s) {
    if (s == null) return null;
    if (s.length <= _previewMax) return s;
    return '${s.substring(0, _previewMax)}…';
  }

  void _longPressCopy(BuildContext context) {
    final HistoryEntry? e = lastEntry;
    if (e == null || e.sensitive) return;
    HapticFeedback.mediumImpact();
    CopyToClipboardUtil.copyToClipboard(context, e.output);
  }

  @override
  Widget build(BuildContext context) {
    final HistoryEntry? e = lastEntry;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: e == null ? null : () => _longPressCopy(context),
      child: InlineToolCard(
        descriptor: descriptor,
        expanded: false,
        onToggle: onTap,
        bodyBuilder: (BuildContext _) => const SizedBox.shrink(),
        previewText: _truncate(e?.input),
        previewSensitive: e?.sensitive ?? false,
      ),
    );
  }
}

class _HeroPasteCard extends StatelessWidget {
  const _HeroPasteCard({
    required this.controller,
    required this.onChanged,
    required this.onPaste,
    required this.onClear,
    required this.onScan,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onPaste;
  final VoidCallback? onClear;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: controller,
          label: 'Paste anything',
          placeholder: 'Timestamp, JSON, hex, base64, color…',
          onChanged: onChanged,
          multiline: true,
          minLines: 2,
          maxLines: 5,
          trailing: Semantics(
            button: true,
            label: 'Scan QR code',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onScan,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(MqIcons.qrCodeScan, size: 22, color: c.textSec),
              ),
            ),
          ),
        ),
        const SizedBox(height: MqSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: MqButton(
                label: 'Paste',
                icon: MqIcons.paste,
                variant: MqButtonVariant.glass,
                onPressed: onPaste,
                full: true,
              ),
            ),
            if (onClear != null) ...<Widget>[
              const SizedBox(width: MqSpacing.sm),
              Expanded(
                child: MqButton(
                  label: 'Clear',
                  icon: MqIcons.clear,
                  variant: MqButtonVariant.glass,
                  onPressed: onClear,
                  full: true,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.matches,
    required this.expanded,
    required this.onTap,
  });

  final List<UtilityDescriptor> matches;
  final UtilityDescriptor? expanded;
  final void Function(UtilityDescriptor) onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Open in',
          style: MqTextStyles.sectionLabel.copyWith(color: c.textSec),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: MqSpacing.sm,
          runSpacing: MqSpacing.sm,
          children: <Widget>[
            for (final UtilityDescriptor u in matches)
              MqChip(
                label: u.name,
                icon: u.icon,
                accent: u == expanded,
                mono: false,
                onTap: () => onTap(u),
              ),
          ],
        ),
      ],
    );
  }
}
