import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../screens/detail/qr_scanner_route.dart';
import '../../state/history_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../utility_catalog.dart';
import '../../utils/history_recorder.dart';
import '../mq/mq_button.dart';
import '../mq/mq_chip.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_icons.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_segmented.dart';
import 'seed_source.dart';

enum QrMode { generate, scan }

class QrCodeBody extends StatefulWidget {
  const QrCodeBody({
    super.key,
    this.initialInput,
    this.seedSource = SeedSource.none,
    this.onSwitchTool,
  });

  final String? initialInput;
  final SeedSource seedSource;
  final QrSwitchToolCallback? onSwitchTool;

  @override
  State<QrCodeBody> createState() => _QrCodeBodyState();
}

class _QrCodeBodyState extends State<QrCodeBody> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey _qrBoundaryKey = GlobalKey();
  Timer? _debounce;
  QrMode _mode = QrMode.generate;
  String? _scanResult;
  bool _exporting = false;

  HistoryRecorder? _recorder;

  @override
  void initState() {
    super.initState();
    final String? seed = widget.initialInput;
    if (seed != null && seed.isNotEmpty) {
      _controller.text = seed;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _recorder ??= HistoryRecorder(
      controller: HistoryScope.of(context),
      utilityId: 'qr_code',
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _recorder?.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onGenerateChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = data?.text;
    if (text == null || text.isEmpty) return;
    setState(() => _controller.text = text);
  }

  void _clear() {
    setState(() => _controller.clear());
  }

  Future<void> _share() async {
    if (_exporting) return;
    final RenderRepaintBoundary? boundary =
        _qrBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return;
    setState(() => _exporting = true);
    try {
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final Uint8List? bytes;
      try {
        final ByteData? png = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        bytes = png?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
      if (bytes == null) return;
      final String fileName =
          'masquerade_qr_${DateTime.now().millisecondsSinceEpoch}.png';
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile.fromData(bytes, mimeType: 'image/png')],
          fileNameOverrides: <String>[fileName],
          subject: 'QR code',
          downloadFallbackEnabled: true,
        ),
      );
    } catch (_) {
      // Best-effort export; swallow render and share failures so the pending
      // Future does not bubble to the framework error overlay. User can retry.
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _openScanner() async {
    final String? result = await pushQrScanner(context);
    if (!mounted || result == null || result.isEmpty) return;
    setState(() => _scanResult = result);
    _recorder?.recordPaste('(camera scan)', result);
  }

  void _openInTool(UtilityDescriptor u, String input) {
    widget.onSwitchTool?.call(u, input);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqSegmented<QrMode>(
          options: const <QrMode, String>{
            QrMode.generate: 'Generate',
            QrMode.scan: 'Scan',
          },
          selected: _mode,
          onChanged: (QrMode m) => setState(() {
            _mode = m;
            if (m == QrMode.scan) _scanResult = null;
          }),
        ),
        const SizedBox(height: MqSpacing.md),
        if (_mode == QrMode.generate) ..._buildGenerate(context),
        if (_mode == QrMode.scan) ..._buildScan(context),
        const SizedBox(height: MqSpacing.lg),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildBottomBar() {
    if (_mode == QrMode.generate) {
      final bool hasInput = _controller.text.trim().isNotEmpty;
      return Row(
        children: <Widget>[
          Expanded(
            child: MqButton(
              label: 'Paste',
              icon: MqIcons.paste,
              variant: MqButtonVariant.glass,
              onPressed: _paste,
              full: true,
            ),
          ),
          const SizedBox(width: MqSpacing.sm),
          Expanded(
            child: MqButton(
              label: _exporting ? 'Sharing…' : 'Share',
              icon: MqIcons.share,
              variant: MqButtonVariant.glass,
              onPressed: hasInput && !_exporting ? _share : null,
              full: true,
            ),
          ),
          const SizedBox(width: MqSpacing.sm),
          Expanded(
            child: MqButton(
              label: 'Clear',
              icon: MqIcons.clear,
              variant: MqButtonVariant.glass,
              onPressed: hasInput ? _clear : null,
              full: true,
            ),
          ),
        ],
      );
    }
    return MqButton(
      label: 'Scan QR',
      icon: MqIcons.qrCodeScan,
      onPressed: _openScanner,
      full: true,
    );
  }

  List<Widget> _buildGenerate(BuildContext context) {
    final String text = _controller.text;
    final c = context.mq.colors;
    return <Widget>[
      MqInput(
        controller: _controller,
        label: 'Text or URL',
        placeholder: 'https://example.com',
        onChanged: _onGenerateChanged,
        multiline: true,
        minLines: 2,
        maxLines: 6,
        mono: false,
      ),
      const SizedBox(height: MqSpacing.lg),
      if (text.trim().isEmpty)
        const MqEmptyHint(label: 'Type text or a URL to render its QR code.')
      else
        Center(
          child: RepaintBoundary(
            key: _qrBoundaryKey,
            child: ColoredBox(
              color: const Color(0xFFFFFFFF),
              child: Padding(
                padding: const EdgeInsets.all(MqSpacing.md),
                child: QrImageView(
                  data: text,
                  size: 240,
                  version: QrVersions.auto,
                  backgroundColor: const Color(0xFFFFFFFF),
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF000000),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF000000),
                  ),
                  errorStateBuilder: (BuildContext _, Object? error) => Padding(
                    padding: const EdgeInsets.all(MqSpacing.md),
                    child: Text(
                      'Input too long for a single QR code.',
                      style: TextStyle(color: c.danger),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildScan(BuildContext context) {
    final String? scan = _scanResult;
    if (scan == null) {
      return const <Widget>[
        MqEmptyHint(label: 'Tap Scan QR to open the camera.'),
      ];
    }
    final List<UtilityDescriptor> detected = UtilityCatalog.detectAll(scan);
    return <Widget>[
      const MqSectionHeader(label: 'Result'),
      MqMonoCell(label: 'Scanned', value: scan, accent: true),
      if (detected.isNotEmpty) ...<Widget>[
        const SizedBox(height: MqSpacing.md),
        const MqSectionHeader(label: 'Open in'),
        Wrap(
          spacing: MqSpacing.sm,
          runSpacing: MqSpacing.sm,
          children: <Widget>[
            for (final UtilityDescriptor u in detected)
              MqChip(
                label: u.name,
                icon: u.icon,
                accent: true,
                mono: false,
                onTap: () => _openInTool(u, scan),
              ),
          ],
        ),
      ],
    ];
  }
}
