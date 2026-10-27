@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/hash_parser.dart';

// Browser-only: on web HashTool.shaDigests goes through crypto.subtle.digest
// (async); it must agree with the package:crypto digests used on native.
void main() {
  test('crypto.subtle digests match package:crypto', () async {
    for (final String input in <String>['', 'abc', 'héllo 😀' * 100]) {
      final List<int> bytes = utf8.encode(input);
      final FutureOr<ShaDigests> web = HashTool.shaDigests(bytes);
      expect(web, isA<Future<ShaDigests>>());
      expect(await web, HashTool.shaDigestsSync(bytes));
    }
  });
}
