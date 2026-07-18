import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/artifact.dart';

typedef ExternalFilePicker =
    Future<XFile?> Function({required List<XTypeGroup> acceptedTypeGroups});
typedef QrImageAnalyzer = Future<BarcodeCapture?> Function(String path);

sealed class ExternalInputResult {
  const ExternalInputResult();
}

class ExternalInputCancelled extends ExternalInputResult {
  const ExternalInputCancelled();
}

class ExternalInputFailure extends ExternalInputResult {
  const ExternalInputFailure(this.message);

  final String message;
}

class ExternalInputSuccess extends ExternalInputResult {
  const ExternalInputSuccess(this.artifact, this.filename);

  final Artifact<Object?> artifact;
  final String filename;
}

/// Imports one user-selected Workbench input without retaining it.
class ExternalInputImporter {
  const ExternalInputImporter({
    ExternalFilePicker? pickFile,
    QrImageAnalyzer? analyzeQrImage,
    bool? supportsQrImages,
  }) : _pickFile = pickFile,
       _analyzeQrImage = analyzeQrImage,
       _supportsQrImages = supportsQrImages;

  static const int maxTextBytes = 65536;
  static const int maxImageBytes = 10 * 1024 * 1024;

  static const Set<String> _textExtensions = <String>{
    'txt',
    'json',
    'jsonc',
    'yaml',
    'yml',
    'toml',
    'xml',
    'plist',
    'conf',
    'config',
    'cfg',
    'ini',
    'env',
    'properties',
    'pem',
    'crt',
    'cer',
  };
  static const Set<String> _imageExtensions = <String>{
    'png',
    'jpg',
    'jpeg',
    'heic',
  };
  static const Set<String> _textMimeTypes = <String>{
    'text/plain',
    'text/json',
    'text/yaml',
    'text/x-yaml',
    'text/xml',
    'application/json',
    'application/json5',
    'application/toml',
    'application/yaml',
    'application/x-yaml',
    'application/xml',
    'application/x-pem-file',
    'application/pem-certificate-chain',
    'application/pkix-cert',
    'application/x-x509-ca-cert',
    'application/octet-stream',
  };
  static const Set<String> _imageMimeTypes = <String>{
    'image/png',
    'image/jpeg',
    'image/heic',
  };

  static const List<XTypeGroup> acceptedTypeGroups = <XTypeGroup>[
    XTypeGroup(
      label: 'Text, config, or certificate',
      extensions: <String>[
        'txt',
        'json',
        'jsonc',
        'yaml',
        'yml',
        'toml',
        'xml',
        'plist',
        'conf',
        'config',
        'cfg',
        'ini',
        'env',
        'properties',
        'pem',
        'crt',
        'cer',
      ],
      mimeTypes: <String>[
        'text/plain',
        'application/json',
        'application/yaml',
        'application/toml',
        'application/xml',
        'application/x-pem-file',
        'application/pkix-cert',
      ],
      uniformTypeIdentifiers: <String>[
        'public.text',
        'public.json',
        'public.xml',
        'com.apple.property-list',
        'public.x509-certificate',
      ],
    ),
    XTypeGroup(
      label: 'QR image',
      extensions: <String>['png', 'jpg', 'jpeg', 'heic'],
      mimeTypes: <String>['image/png', 'image/jpeg', 'image/heic'],
      uniformTypeIdentifiers: <String>[
        'public.png',
        'public.jpeg',
        'public.heic',
      ],
    ),
  ];

  final ExternalFilePicker? _pickFile;
  final QrImageAnalyzer? _analyzeQrImage;
  final bool? _supportsQrImages;

  Future<ExternalInputResult> pick() async {
    final XFile? file;
    try {
      file = await (_pickFile ?? openFile)(
        acceptedTypeGroups: acceptedTypeGroups,
      );
    } catch (_) {
      return const ExternalInputFailure('The file picker could not be opened.');
    }
    if (file == null) return const ExternalInputCancelled();

    final String extension = _extension(file.name);
    final bool isText = _textExtensions.contains(extension);
    final bool isImage = _imageExtensions.contains(extension);
    if (!isText && !isImage) {
      return const ExternalInputFailure('That file type is not supported.');
    }
    final String? mimeType = file.mimeType?.toLowerCase().split(';').first;
    if (mimeType != null &&
        !(isText
            ? _textMimeTypes.contains(mimeType)
            : _imageMimeTypes.contains(mimeType))) {
      return const ExternalInputFailure('That file type is not supported.');
    }

    final int length;
    try {
      length = await file.length();
    } catch (_) {
      return const ExternalInputFailure('File details could not be read.');
    }
    if (length <= 0) {
      return const ExternalInputFailure('The selected file is empty.');
    }
    final int limit = isImage ? maxImageBytes : maxTextBytes;
    if (length > limit) {
      return ExternalInputFailure(
        isImage
            ? 'QR images must be 10 MB or smaller.'
            : 'Text files must be 64 KB or smaller.',
      );
    }

    return isImage ? _decodeQr(file) : _readText(file);
  }

  Future<ExternalInputResult> _readText(XFile file) async {
    final List<int> bytes = <int>[];
    try {
      await for (final Uint8List chunk in file.openRead()) {
        final int remaining = maxTextBytes + 1 - bytes.length;
        bytes.addAll(chunk.length <= remaining ? chunk : chunk.take(remaining));
        if (bytes.length > maxTextBytes) break;
      }
    } catch (_) {
      return const ExternalInputFailure('The selected file could not be read.');
    }
    if (bytes.isEmpty) {
      return const ExternalInputFailure('The selected file is empty.');
    }
    if (bytes.length > maxTextBytes) {
      return const ExternalInputFailure('Text files must be 64 KB or smaller.');
    }
    final String value;
    try {
      value = utf8.decode(bytes);
    } on FormatException {
      return const ExternalInputFailure('The selected file is not UTF-8 text.');
    }
    if (_containsBinaryControls(value)) {
      return const ExternalInputFailure('Binary files are not supported.');
    }
    return ExternalInputSuccess(
      Artifact<Object?>(
        kind: ArtifactKind.unknown,
        rawValue: value,
        provenance: ArtifactProvenance.fileImport,
      ),
      file.name,
    );
  }

  Future<ExternalInputResult> _decodeQr(XFile file) async {
    final bool supported =
        _supportsQrImages ??
        (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.macOS));
    if (!supported) {
      return const ExternalInputFailure(
        'QR image decoding is not supported on this platform.',
      );
    }
    if (file.path.isEmpty) {
      return const ExternalInputFailure(
        'QR image decoding is not supported for this file.',
      );
    }
    final BarcodeCapture? capture;
    try {
      capture = await (_analyzeQrImage ?? _analyzeQr)(file.path);
    } on UnsupportedError {
      return const ExternalInputFailure(
        'QR image decoding is not supported on this device.',
      );
    } catch (_) {
      return const ExternalInputFailure('The QR image could not be decoded.');
    }
    final Set<String> values = <String>{
      for (final Barcode barcode in capture?.barcodes ?? const <Barcode>[])
        if (barcode.rawValue case final String value when value.isNotEmpty)
          value,
    };
    if (values.length > 1) {
      return const ExternalInputFailure(
        'The image contains more than one QR code.',
      );
    }
    if (values.isNotEmpty) {
      final String value = values.single;
      return ExternalInputSuccess(
        Artifact<Object?>(
          kind: ArtifactKind.unknown,
          rawValue: value,
          provenance: ArtifactProvenance.qrImageImport,
        ),
        file.name,
      );
    }
    return const ExternalInputFailure('No QR code was found in that image.');
  }

  static Future<BarcodeCapture?> _analyzeQr(String path) async {
    final MobileScannerController controller = MobileScannerController(
      formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    );
    try {
      return await controller.analyzeImage(
        path,
        formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
      );
    } finally {
      await controller.dispose();
    }
  }

  static String _extension(String name) {
    final int dot = name.lastIndexOf('.');
    return dot < 0 || dot == name.length - 1
        ? ''
        : name.substring(dot + 1).toLowerCase();
  }

  static bool _containsBinaryControls(String value) => value.runes.any(
    (int rune) =>
        rune == 0 ||
        (rune < 0x20 && rune != 0x09 && rune != 0x0A && rune != 0x0D),
  );
}
