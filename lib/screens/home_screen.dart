import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/mq_metrics.dart';
import '../theme/mq_theme.dart';
import '../theme/mq_typography.dart';
import '../utility_catalog.dart';
import '../widgets/mq/inline_tool_card.dart';
import '../widgets/mq/mq_button.dart';
import '../widgets/mq/mq_chip.dart';
import '../widgets/mq/mq_icons.dart';
import '../widgets/mq/mq_input.dart';
import '../widgets/mq/mq_section_header.dart';
import '../widgets/tool_bodies/base64_body.dart';
import '../widgets/tool_bodies/bps_body.dart';
import '../widgets/tool_bodies/bytes_body.dart';
import '../widgets/tool_bodies/color_body.dart';
import '../widgets/tool_bodies/json_body.dart';
import '../widgets/tool_bodies/number_base_body.dart';
import '../widgets/tool_bodies/qr_code_body.dart';
import '../widgets/tool_bodies/seed_source.dart';
import '../widgets/tool_bodies/timestamp_body.dart';
import 'detail/qr_scanner_route.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _heroController = TextEditingController();
  Timer? _debounce;
  List<UtilityDescriptor> _matches = const <UtilityDescriptor>[];

  String? _expandedToolId;
  String? _expandedSeed;
  SeedSource _expandedSeedSource = SeedSource.none;

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
    setState(() {
      _matches = UtilityCatalog.detectAll(_heroController.text);
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
    setState(() => _matches = const <UtilityDescriptor>[]);
  }

  Future<void> _scanToHero() async {
    final String? result = await pushQrScanner(context);
    if (!mounted || result == null || result.isEmpty) return;
    _heroController.text = result;
    _recomputeMatches();
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

  void _openFromChip(UtilityDescriptor u) {
    _toggle(u, seed: _heroController.text, source: SeedSource.paste);
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
    final bool hasInput = _heroController.text.trim().isNotEmpty;

    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: SafeArea(
        bottom: false,
        child: ListView(
          // Cards span edge-to-edge so the body interior has the same width
          // an MqDetailScaffold child gets at the same surface size — this
          // matters for the 3-button bottom bar inside Base64/Bytes/QR.
          padding: const EdgeInsets.fromLTRB(
            0,
            MqSpacing.sm,
            0,
            MqLayout.tabBarClearance,
          ),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MqSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          style: MqTextStyles.caption1.copyWith(
                            color: c.textSec,
                          ),
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
                    _SuggestionRow(matches: _matches, onTap: _openFromChip),
                  ],
                  const SizedBox(height: MqSpacing.lg),
                  const MqSectionHeader(label: 'All tools'),
                  const SizedBox(height: MqSpacing.sm),
                ],
              ),
            ),
            for (final UtilityDescriptor u in UtilityCatalog.all) ...<Widget>[
              InlineToolCard(
                descriptor: u,
                expanded: _expandedToolId == u.id,
                onToggle: () => _toggle(u),
                bodyBuilder: (BuildContext ctx) => _buildBody(ctx, u),
              ),
              const SizedBox(height: MqSpacing.sm),
            ],
          ],
        ),
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
  const _SuggestionRow({required this.matches, required this.onTap});

  final List<UtilityDescriptor> matches;
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
                accent: true,
                mono: false,
                onTap: () => onTap(u),
              ),
          ],
        ),
      ],
    );
  }
}
