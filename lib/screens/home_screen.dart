import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/mq_metrics.dart';
import '../theme/mq_theme.dart';
import '../theme/mq_typography.dart';
import '../utility_catalog.dart';
import '../widgets/mq/compact_paste_bar.dart';
import '../widgets/mq/mq_button.dart';
import '../widgets/mq/mq_empty_hint.dart';
import '../widgets/mq/mq_icons.dart';
import '../widgets/mq/mq_surface.dart';
import '../widgets/mq/section_rule.dart';
import 'detail/qr_scanner_route.dart';
import 'detail/tool_detail_route.dart';

enum _WorkbenchState { empty, artifact, search, unknown }

/// Mobile capture surface. Library owns catalog browsing; Workbench only
/// suggests tools for the current explicit input.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenTool, this.navigationBar});

  final OpenInToolCallback? onOpenTool;
  final ObstructingPreferredSizeWidget? navigationBar;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _hero = TextEditingController();
  final FocusNode _heroFocus = FocusNode();
  bool _showRawText = false;

  @override
  void initState() {
    super.initState();
    _hero.addListener(_onHeroChange);
    _heroFocus.addListener(_rebuild);
  }

  @override
  void dispose() {
    _hero.removeListener(_onHeroChange);
    _heroFocus.removeListener(_rebuild);
    _hero.dispose();
    _heroFocus.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onHeroChange() {
    if (!mounted) return;
    setState(() => _showRawText = false);
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = data?.text;
    if (text != null && text.isNotEmpty) _hero.text = text;
  }

  void _clear() => _hero.clear();

  Future<void> _scan() async {
    final String? result = await pushQrScanner(context);
    if (mounted && result != null && result.isNotEmpty) _hero.text = result;
  }

  void _open(UtilityDescriptor tool) {
    final String input = _hero.text;
    final OpenInToolCallback? open = widget.onOpenTool;
    if (open != null) {
      open(tool, input);
    } else {
      ToolDetailRoute.push(context, tool, seed: input);
    }
  }

  Future<void> _chooseTool() async {
    final UtilityDescriptor? choice =
        await showCupertinoModalPopup<UtilityDescriptor>(
          context: context,
          builder: (BuildContext context) => CupertinoActionSheet(
            title: const Text('Send to tool'),
            actions: <Widget>[
              for (final UtilityDescriptor tool in UtilityCatalog.all)
                CupertinoActionSheetAction(
                  onPressed: () => Navigator.of(context).pop(tool),
                  child: Text(tool.name),
                ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
        );
    if (mounted && choice != null) _open(choice);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final String input = _hero.text.trim();
    final List<UtilityDescriptor> detected = UtilityCatalog.detectAll(input);
    final bool hasShape = detected.any(
      (UtilityDescriptor tool) => tool.detect(input),
    );
    final List<UtilityDescriptor> nameMatches = hasShape
        ? const <UtilityDescriptor>[]
        : UtilityCatalog.searchStable(input);
    final _WorkbenchState state = input.isEmpty
        ? _WorkbenchState.empty
        : hasShape
        ? _WorkbenchState.artifact
        : nameMatches.isNotEmpty
        ? _WorkbenchState.search
        : _WorkbenchState.unknown;
    final List<UtilityDescriptor> suggestions = hasShape
        ? detected
        : nameMatches;

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
            CompactPasteBar(
              controller: _hero,
              focusNode: _heroFocus,
              onPaste: _paste,
              onClear: _clear,
              onScan: _scan,
            ),
            _result(context, state, suggestions),
            const SectionRule(label: 'Current session'),
            const MqEmptyHint(label: 'No current session'),
            const SectionRule(label: 'Saved workflows'),
            const MqEmptyHint(label: 'No saved workflows'),
          ],
        ),
      ),
    );
  }

  Widget _result(
    BuildContext context,
    _WorkbenchState state,
    List<UtilityDescriptor> suggestions,
  ) {
    final c = context.mq.colors;
    if (state == _WorkbenchState.empty) {
      return Semantics(
        container: true,
        liveRegion: true,
        label: 'Empty Workbench',
        child: const MqEmptyHint(
          label: 'Capture something to begin',
          detail: 'Type, paste, or scan a QR code.',
        ),
      );
    }

    if (state == _WorkbenchState.unknown) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SectionRule(label: 'Result'),
          Semantics(
            container: true,
            liveRegion: true,
            label: 'Unknown text. Open as text or send to a tool.',
            child: MqSurface(
              background: c.warningBg,
              borderColor: c.warning,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Unknown text',
                    style: MqTextStyles.headline.copyWith(color: c.textPri),
                  ),
                  const SizedBox(height: MqSpacing.xs),
                  Text(
                    'No tool matched this value.',
                    style: MqTextStyles.body.copyWith(color: c.textSec),
                  ),
                  const SizedBox(height: MqSpacing.md),
                  MqButton(
                    label: 'Open as text',
                    variant: MqButtonVariant.glass,
                    onPressed: () => setState(() => _showRawText = true),
                    full: true,
                  ),
                  const SizedBox(height: MqSpacing.sm),
                  MqButton(
                    label: 'Send to tool',
                    variant: MqButtonVariant.tinted,
                    onPressed: _chooseTool,
                    full: true,
                  ),
                ],
              ),
            ),
          ),
          if (_showRawText) ...<Widget>[
            const SectionRule(label: 'Text'),
            Semantics(
              container: true,
              label: 'Opened text: ${_hero.text}',
              child: MqSurface(
                child: Text(
                  _hero.text,
                  style: MqTextStyles.monoMd.copyWith(color: c.monoText),
                ),
              ),
            ),
          ],
        ],
      );
    }

    final bool artifact = state == _WorkbenchState.artifact;
    final String title = artifact ? 'Artifact detected' : 'Tool search';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionRule(label: 'Tool suggestions'),
        Semantics(
          container: true,
          liveRegion: true,
          label: '$title. ${suggestions.length} suggestions.',
          child: MqSurface(
            background: artifact ? c.successBg : c.accentBg,
            borderColor: artifact ? c.success : c.info,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  title,
                  style: MqTextStyles.headline.copyWith(color: c.textPri),
                ),
                const SizedBox(height: MqSpacing.sm),
                for (final UtilityDescriptor tool in suggestions)
                  _SuggestionRow(tool: tool, onTap: () => _open(tool)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.tool, required this.onTap});

  final UtilityDescriptor tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Semantics(
      label: 'Open ${tool.name}',
      button: true,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: MqSpacing.sm),
        minimumSize: const Size.fromHeight(44),
        onPressed: onTap,
        child: Row(
          children: <Widget>[
            Icon(tool.icon, size: 18, color: tool.tint),
            const SizedBox(width: MqSpacing.sm),
            Expanded(
              child: Text(
                tool.name,
                style: MqTextStyles.body.copyWith(color: c.textPri),
              ),
            ),
            Icon(MqIcons.chevR, size: 16, color: c.textTer),
          ],
        ),
      ),
    );
  }
}
