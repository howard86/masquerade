import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/hex_codec.dart';

void main() {
  test('encode is lowercase without separators', () {
    expect(HexCodec.encode(<int>[0x48, 0x69, 0xab]), '4869ab');
    expect(HexCodec.encode(<int>[]), '');
  });

  test('decode accepts any case and rejects malformed input', () {
    expect(HexCodec.decode('4869AB'), <int>[0x48, 0x69, 0xab]);
    expect(HexCodec.decode(''), isEmpty);
    expect(HexCodec.decode('486'), isNull);
    expect(HexCodec.decode('zz'), isNull);
  });
}
