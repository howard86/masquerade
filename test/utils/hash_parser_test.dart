import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/utils/hash_parser.dart';

void main() {
  group('HashTool — known-answer vectors', () {
    test('md5Hex empty string', () {
      expect(
        HashTool.md5Hex(utf8.encode('')),
        'd41d8cd98f00b204e9800998ecf8427e',
      );
    });

    test('sha1Hex "abc"', () {
      expect(
        HashTool.sha1Hex(utf8.encode('abc')),
        'a9993e364706816aba3e25717850c26c9cd0d89d',
      );
    });

    test('sha256Hex "abc"', () {
      expect(
        HashTool.sha256Hex(utf8.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('sha512Hex empty string', () {
      expect(
        HashTool.sha512Hex(utf8.encode('')),
        'cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce'
        '47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e',
      );
    });
  });

  group('HashTool.identify', () {
    test('64-char hex → SHA-256', () {
      final HashIdentifyResult result = HashTool.identify('a' * 64);
      expect(result, isA<HashShape>());
      expect((result as HashShape).name, 'SHA-256');
      expect(result.bitLength, 256);
    });

    test('40-char hex → SHA-1', () {
      final HashIdentifyResult result = HashTool.identify('a' * 40);
      expect(result, isA<HashShape>());
      expect((result as HashShape).name, 'SHA-1');
      expect(result.bitLength, 160);
    });

    test('32-char hex → MD5', () {
      final HashIdentifyResult result = HashTool.identify('a' * 32);
      expect(result, isA<HashShape>());
      expect((result as HashShape).name, 'MD5');
    });

    test('128-char hex → SHA-512', () {
      final HashIdentifyResult result = HashTool.identify('a' * 128);
      expect(result, isA<HashShape>());
      expect((result as HashShape).name, 'SHA-512');
    });

    test('96-char hex → SHA-384', () {
      final HashIdentifyResult result = HashTool.identify('a' * 96);
      expect(result, isA<HashShape>());
      expect((result as HashShape).name, 'SHA-384');
    });

    test('non-hex input → HashUnknown', () {
      expect(HashTool.identify('xyz'), isA<HashUnknown>());
    });

    test('empty input → HashUnknown', () {
      expect(HashTool.identify(''), isA<HashUnknown>());
    });

    test('hex of non-standard length → HashUnknown', () {
      expect(HashTool.identify('abcdef'), isA<HashUnknown>());
    });
  });
}
