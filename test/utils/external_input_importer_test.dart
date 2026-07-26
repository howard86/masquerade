import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/utils/external_input_importer.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class _File extends XFile {
  _File({
    required this.filename,
    required this.metadataLength,
    required this.bytes,
    this.type,
    String path = '/tmp/import',
  }) : super(path);

  final String filename;
  final int metadataLength;
  final Uint8List bytes;
  final String? type;
  bool opened = false;
  int chunksRead = 0;

  @override
  String get name => filename;

  @override
  String? get mimeType => type;

  @override
  Future<int> length() async => metadataLength;

  @override
  Stream<Uint8List> openRead([int? start, int? end]) async* {
    opened = true;
    for (int offset = 0; offset < bytes.length; offset += 16384) {
      chunksRead++;
      yield Uint8List.sublistView(
        bytes,
        offset,
        (offset + 16384).clamp(0, bytes.length),
      );
    }
  }
}

ExternalInputImporter _importer(
  XFile? file, {
  QrImageAnalyzer? analyze,
  bool supportsQr = false,
}) => ExternalInputImporter(
  pickFile: ({required List<XTypeGroup> acceptedTypeGroups}) async => file,
  analyzeQrImage: analyze,
  supportsQrImages: supportsQr,
);

void main() {
  test('cancellation is silent', () async {
    expect(await _importer(null).pick(), isA<ExternalInputCancelled>());
  });

  test('accepts exactly 64 KiB of UTF-8 JSON', () async {
    final Uint8List bytes = Uint8List.fromList(
      '{"a":"${'x' * 65528}"}'.codeUnits,
    );
    expect(bytes.length, ExternalInputImporter.maxTextBytes);

    final ExternalInputResult result = await _importer(
      _File(
        filename: 'fixture.json',
        metadataLength: bytes.length,
        bytes: bytes,
        type: 'application/json',
      ),
    ).pick();

    expect(result, isA<ExternalInputSuccess>());
    expect(
      (result as ExternalInputSuccess).artifact.provenance,
      ArtifactProvenance.fileImport,
    );
  });

  test('rejects 64 KiB plus one from metadata before reading', () async {
    final _File file = _File(
      filename: 'large.txt',
      metadataLength: ExternalInputImporter.maxTextBytes + 1,
      bytes: Uint8List(1),
      type: 'text/plain',
    );

    final ExternalInputResult result = await _importer(file).pick();

    expect((result as ExternalInputFailure).message, contains('64 KB'));
    expect(file.opened, isFalse);
  });

  test('rechecks the cap after reading', () async {
    final _File file = _File(
      filename: 'changed.txt',
      metadataLength: ExternalInputImporter.maxTextBytes,
      bytes: Uint8List(ExternalInputImporter.maxTextBytes * 4),
      type: 'text/plain',
    );

    final ExternalInputResult result = await _importer(file).pick();

    expect((result as ExternalInputFailure).message, contains('64 KB'));
    expect(file.opened, isTrue);
    expect(file.chunksRead, 5);
  });

  test('rejects mismatched MIME, invalid UTF-8, and binary controls', () async {
    final List<_File> files = <_File>[
      _File(
        filename: 'fixture.json',
        metadataLength: 2,
        bytes: Uint8List.fromList(<int>[123, 125]),
        type: 'image/png',
      ),
      _File(
        filename: 'fixture.pem',
        metadataLength: 1,
        bytes: Uint8List.fromList(<int>[0xFF]),
      ),
      _File(
        filename: 'fixture.cfg',
        metadataLength: 3,
        bytes: Uint8List.fromList(<int>[65, 0, 66]),
      ),
    ];

    final List<String> errors = <String>[];
    for (final _File file in files) {
      errors.add(
        ((await _importer(file).pick()) as ExternalInputFailure).message,
      );
    }

    expect(errors[0], contains('type'));
    expect(files[0].opened, isFalse);
    expect(errors[1], contains('UTF-8'));
    expect(errors[2], contains('Binary'));
  });

  test('decodes one distinct QR value without reading image bytes', () async {
    final _File image = _File(
      filename: 'qr.png',
      metadataLength: 100,
      bytes: Uint8List(100),
      type: 'image/png',
      path: '/tmp/qr.png',
    );
    String? analyzedPath;
    final ExternalInputResult result = await _importer(
      image,
      supportsQr: true,
      analyze: (String path) async {
        analyzedPath = path;
        return const BarcodeCapture(
          barcodes: <Barcode>[
            Barcode(rawValue: 'https://example.com'),
            Barcode(rawValue: 'https://example.com'),
          ],
        );
      },
    ).pick();

    expect(analyzedPath, '/tmp/qr.png');
    expect(image.opened, isFalse);
    expect(result, isA<ExternalInputSuccess>());
    expect(
      (result as ExternalInputSuccess).artifact.provenance,
      ArtifactProvenance.qrImageImport,
    );
    expect(result.artifact.rawValue, 'https://example.com');
  });

  test('rejects ambiguous QR images and an empty analysis path', () async {
    final ExternalInputResult ambiguous = await _importer(
      _File(
        filename: 'qr.jpg',
        metadataLength: 100,
        bytes: Uint8List(100),
        path: '/tmp/qr.jpg',
      ),
      supportsQr: true,
      analyze: (_) async => const BarcodeCapture(
        barcodes: <Barcode>[
          Barcode(rawValue: 'first'),
          Barcode(rawValue: 'second'),
        ],
      ),
    ).pick();
    bool analyzed = false;
    final ExternalInputResult emptyPath = await _importer(
      _File(
        filename: 'qr.png',
        metadataLength: 100,
        bytes: Uint8List(100),
        path: '',
      ),
      supportsQr: true,
      analyze: (_) async {
        analyzed = true;
        return const BarcodeCapture();
      },
    ).pick();

    expect((ambiguous as ExternalInputFailure).message, contains('more than'));
    expect((emptyPath as ExternalInputFailure).message, contains('supported'));
    expect(analyzed, isFalse);
  });

  test('reports no QR and unsupported image analysis clearly', () async {
    _File image() => _File(
      filename: 'qr.png',
      metadataLength: 100,
      bytes: Uint8List(100),
      path: '/tmp/qr.png',
    );

    final ExternalInputResult none = await _importer(
      image(),
      supportsQr: true,
      analyze: (_) async => const BarcodeCapture(),
    ).pick();
    final ExternalInputResult unsupported = await _importer(
      image(),
      supportsQr: true,
      analyze: (_) async => throw UnsupportedError('simulator'),
    ).pick();

    expect((none as ExternalInputFailure).message, contains('No QR'));
    expect(
      (unsupported as ExternalInputFailure).message,
      contains('not supported'),
    );
  });
}
