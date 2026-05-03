import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../state/history_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../utility_catalog.dart';
import '../../widgets/mq/mq_button.dart';
import '../../widgets/mq/mq_chip.dart';
import '../../widgets/mq/mq_empty_hint.dart';
import '../../widgets/mq/mq_icons.dart';
import '../../widgets/mq/mq_input.dart';
import '../../widgets/mq/mq_mono_cell.dart';
import '../../widgets/mq/mq_section_header.dart';
import '../../widgets/mq/mq_segmented.dart';
import 'detail_scaffold.dart';
import 'qr_scanner_route.dart';

enum QrMode { generate, scan }

class QrCodeScreen extends StatefulWidget {
  const QrCodeScreen({super.key, this.initialInput});

  final String? initialInput;

  @override
  State<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends State<QrCodeScreen> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey _qrBoundaryKey = GlobalKey();
  Timer? _debounce;
  QrMode _mode = QrMode.generate;
  String? _scanResult;
  File? _lastExport;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final String? seed = widget.initialInput;
    if (seed != null && seed.isNotEmpty) {
      _controller.text = seed;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _lastExport?.delete().ignore();
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
      final ByteData? png = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (png == null) return;
      final Uint8List bytes = png.buffer.asUint8List();
      await _deletePriorExport();
      final String fileName =
          'masquerade_qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final File file = File('${Directory.systemTemp.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      _lastExport = file;
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'image/png')],
          subject: 'QR code',
        ),
      );
    } catch (_) {
      // Share failures are surfaced by the OS share sheet; swallow here so the
      // pending Future does not bubble to the framework error overlay.
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _deletePriorExport() async {
    final File? prior = _lastExport;
    if (prior == null) return;
    _lastExport = null;
    try {
      await prior.delete();
    } catch (_) {
      // Best-effort cleanup; ignore IO errors.
    }
  }

  Future<void> _openScanner() async {
    final String? result = await pushQrScanner(context);
    if (!mounted || result == null || result.isEmpty) return;
    setState(() => _scanResult = result);
    HistoryScope.of(context).add(
      HistoryEntry(
        utilityId: 'qr_code',
        input: '(camera scan)',
        output: result,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MqDetailScaffold(
      title: 'QR Code',
      subtitle: 'Generate QR from text · scan QR with camera.',
      bottomBar: _buildBottomBar(),
      child: Column(
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
        ],
      ),
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
                onTap: () => u.push(context, initialInput: scan),
              ),
          ],
        ),
      ],
    ];
  }
}
