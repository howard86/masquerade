import 'dart:js_interop';
import 'dart:typed_data';

import 'hash_parser.dart';

/// SHA-1/256/512 via the browser's `crypto.subtle.digest`, or null when
/// SubtleCrypto is unavailable (non-secure context).
Future<ShaDigests>? subtleShaDigests(List<int> bytes) {
  final _SubtleCrypto? subtle = _subtle;
  if (subtle == null) return null;
  final JSUint8Array data =
      (bytes is Uint8List ? bytes : Uint8List.fromList(bytes)).toJS;
  Future<String> digest(String algorithm) => subtle
      .digest(algorithm.toJS, data)
      .toDart
      .then((JSArrayBuffer buffer) => _hex(buffer.toDart.asUint8List()));
  return Future.wait(<Future<String>>[
    digest('SHA-1'),
    digest('SHA-256'),
    digest('SHA-512'),
  ]).then((List<String> hex) => (sha1: hex[0], sha256: hex[1], sha512: hex[2]));
}

String _hex(Uint8List bytes) {
  const String digits = '0123456789abcdef';
  final StringBuffer out = StringBuffer();
  for (final int byte in bytes) {
    out
      ..write(digits[byte >> 4])
      ..write(digits[byte & 0x0f]);
  }
  return out.toString();
}

@JS('crypto.subtle')
external _SubtleCrypto? get _subtle;

extension type _SubtleCrypto._(JSObject _) implements JSObject {
  external JSPromise<JSArrayBuffer> digest(
    JSString algorithm,
    JSUint8Array data,
  );
}
