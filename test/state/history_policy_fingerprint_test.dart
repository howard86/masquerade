import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/utils/sensitive_data_policy.dart';

/// Fingerprint of everything that decides what history may store: the
/// SensitiveDataPolicy source (regexes and scan logic; comments and
/// whitespace stripped), `isSensitiveTool` per catalog id, and the catalog's
/// id -> historyPolicy map. Recorded for [HistoryController.policyVersion].
const String _recordedFingerprint =
    '5fad3a87a6abe4571b0388b48a7ca481e54966dbc28d0d9a55a2415f77201516';
const int _recordedPolicyVersion = 1;

String _fingerprint() {
  final String policySource = File('lib/utils/sensitive_data_policy.dart')
      .readAsStringSync()
      .replaceAll('\r\n', '\n')
      .split('\n')
      .where((String l) => !l.trimLeft().startsWith('//'))
      .join('\n')
      .replaceAll(RegExp(r'\s+'), ' ');
  final List<String> tools = <String>[
    for (final UtilityDescriptor d in UtilityCatalog.all)
      '${d.id}:${d.historyPolicy.name}:${SensitiveDataPolicy.isSensitiveTool(d.id)}',
  ]..sort();
  return sha256
      .convert(utf8.encode('$policySource\n${tools.join('\n')}'))
      .toString();
}

void main() {
  test('history policy inputs match the recorded fingerprint', () {
    expect(
      HistoryController.policyVersion,
      _recordedPolicyVersion,
      reason:
          'HistoryController.policyVersion changed: record the new version '
          'and fingerprint in this test.',
    );
    expect(
      _fingerprint(),
      _recordedFingerprint,
      reason:
          'SensitiveDataPolicy, isSensitiveTool or a catalog historyPolicy '
          'changed what history may store: bump '
          'HistoryController.policyVersion, then update '
          '_recordedFingerprint and _recordedPolicyVersion in this test.',
    );
  });
}
