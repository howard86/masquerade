import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/models/content_type.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/utils/sensitive_data_policy.dart';

void main() {
  group('Library catalog metadata', () {
    test('every tool has complete typed routing metadata', () {
      for (final UtilityDescriptor tool in UtilityCatalog.all) {
        expect(
          tool.acceptedTypes.isEmpty,
          tool.id == 'generator',
          reason: '${tool.id} accepts',
        );
        expect(tool.producedTypes, isNotEmpty, reason: tool.id);
        expect(
          tool.inputSources.isEmpty,
          tool.id == 'generator',
          reason: '${tool.id} inputs',
        );
        expect(tool.quickActions, isNotEmpty, reason: tool.id);
      }
      expect(
        UtilityCatalog.all
            .where((UtilityDescriptor tool) => tool.batchCapable)
            .map((UtilityDescriptor tool) => tool.id),
        <String>['list'],
      );
    });

    test('Generator is explicitly source-only', () {
      final UtilityDescriptor generator = UtilityCatalog.byId('generator');
      expect(generator.acceptedTypes, isEmpty);
      expect(generator.inputSources, isEmpty);
      expect(generator.producedTypes, <ContentType>{ContentType.text});
      expect(
        generator.quickActions,
        containsAll(<UtilityQuickAction>{
          UtilityQuickAction.copy,
          UtilityQuickAction.openIn,
        }),
      );
      expect(generator.metadataSummary, startsWith('none → text'));
    });

    test('sensitivity and history policy stay aligned with protection', () {
      for (final UtilityDescriptor tool in UtilityCatalog.all) {
        final bool sensitive = SensitiveDataPolicy.isSensitiveTool(tool.id);
        expect(
          tool.sensitivity == UtilitySensitivity.sensitive,
          sensitive,
          reason: tool.id,
        );
        expect(
          tool.historyPolicy,
          sensitive ? HistoryPolicy.disabled : HistoryPolicy.enabled,
          reason: tool.id,
        );
      }
    });

    test('desktop live-link capability is catalog metadata', () {
      const Map<String, Set<ContentType>> expected = <String, Set<ContentType>>{
        'base64': <ContentType>{ContentType.text},
        'json': <ContentType>{ContentType.text},
        'number_base': <ContentType>{ContentType.number},
        'math': <ContentType>{ContentType.number, ContentType.epoch},
        'timestamp': <ContentType>{ContentType.epoch, ContentType.number},
        'list': <ContentType>{ContentType.lines, ContentType.text},
        'diff': <ContentType>{ContentType.text, ContentType.lines},
        'color': <ContentType>{ContentType.color, ContentType.text},
      };
      expect(<String, Set<ContentType>>{
        for (final UtilityDescriptor tool in UtilityCatalog.all)
          if (tool.liveLinkTypes.isNotEmpty) tool.id: tool.liveLinkTypes,
      }, expected);
      for (final UtilityDescriptor tool in UtilityCatalog.all) {
        expect(
          tool.inputSources.contains(UtilityInputSource.liveLink),
          tool.liveLinkTypes.isNotEmpty,
          reason: tool.id,
        );
        expect(tool.acceptedTypes, containsAll(tool.liveLinkTypes));
      }
    });

    test(
      'every tool is categorized and every category preserves catalog order',
      () {
        final List<String> allIds = UtilityCatalog.all
            .map((UtilityDescriptor u) => u.id)
            .toList();

        expect(
          UtilityCatalog.all.every(
            (UtilityDescriptor u) => u.categories.isNotEmpty,
          ),
          isTrue,
        );
        for (final UtilityCategory category in UtilityCategory.values) {
          final List<UtilityDescriptor> tools = UtilityCatalog.inCategory(
            category,
          );
          expect(tools, isNotEmpty, reason: category.label);
          expect(
            tools.map((UtilityDescriptor u) => u.id),
            allIds.where(
              (String id) =>
                  category == UtilityCategory.all ||
                  UtilityCatalog.byId(id).categories.contains(category),
            ),
          );
        }
      },
    );

    test(
      'every tool is searchable without changing catalog-relative order',
      () {
        for (final UtilityDescriptor tool in UtilityCatalog.all) {
          expect(
            UtilityCatalog.searchStable(tool.name),
            contains(tool),
            reason: tool.name,
          );
        }

        final List<UtilityDescriptor> results = UtilityCatalog.searchStable(
          'encode',
        );
        final List<String> allIds = UtilityCatalog.all
            .map((UtilityDescriptor u) => u.id)
            .toList();
        expect(
          results.map((UtilityDescriptor u) => allIds.indexOf(u.id)),
          orderedEquals(
            results.map((UtilityDescriptor u) => allIds.indexOf(u.id)).toList()
              ..sort(),
          ),
        );
      },
    );
  });

  group('typed compatible next steps', () {
    test('keeps value-shape detection and filters by content type', () {
      expect(
        UtilityCatalog.compatibleNextSteps(
          'base64',
          '{"a":1}',
        ).map((UtilityDescriptor tool) => tool.id),
        contains('json'),
      );
      expect(
        UtilityCatalog.compatibleNextSteps('math', '#336699'),
        isEmpty,
        reason: 'Math produces numbers, not color or text artifacts.',
      );
    });

    test('unknown source ids fail closed', () {
      expect(
        UtilityCatalog.compatibleNextSteps('removed-tool', '{"a":1}'),
        isEmpty,
      );
    });
  });

  group('UtilityCatalog.detectArtifacts', () {
    test('empty input returns empty', () {
      expect(UtilityCatalog.detectArtifacts(''), isEmpty);
      expect(UtilityCatalog.detectArtifacts('   '), isEmpty);
    });

    test('unix timestamp value surfaces ranked Timestamp evidence', () {
      final List<DetectionMatch<Object?>> matches =
          UtilityCatalog.detectArtifacts('1714972800');
      expect(matches.first.primaryToolId, 'timestamp');
      expect(matches.first.artifact.kind, ArtifactKind.timestamp);
    });

    test(
      'certificates route to X.509 while public keys still route to Hash',
      () {
        final String certificate = File(
          'test/fixtures/x509_leaf.pem',
        ).readAsStringSync();
        expect(
          UtilityCatalog.detectArtifacts(
            certificate,
          ).map((DetectionMatch<Object?> match) => match.primaryToolId),
          contains('x509_inspector'),
        );
        const String publicKey =
            '-----BEGIN PUBLIC KEY-----\nAQID\n-----END PUBLIC KEY-----';
        expect(
          UtilityCatalog.detectArtifacts(
            publicKey,
          ).map((DetectionMatch<Object?> match) => match.primaryToolId),
          contains('hash'),
        );
      },
    );

    test('hex color surfaces Color via shape', () {
      final List<DetectionMatch<Object?>> matches =
          UtilityCatalog.detectArtifacts('#1F4FB8');
      expect(
        matches.any((DetectionMatch<Object?> m) => m.primaryToolId == 'color'),
        isTrue,
      );
    });

    test('catalog names never become artifact matches', () {
      final Map<String, List<String>> falsePositives = <String, List<String>>{};
      for (final UtilityDescriptor tool in UtilityCatalog.all) {
        final List<DetectionMatch<Object?>> matches =
            UtilityCatalog.detectArtifacts(tool.name);
        if (matches.isNotEmpty) {
          falsePositives[tool.name] = matches
              .map((match) => '${match.artifact.kind.name}: ${match.reason}')
              .toList();
        }
        expect(
          UtilityCatalog.searchByName(tool.name).map((entry) => entry.id),
          contains(tool.id),
          reason: tool.name,
        );
      }
      expect(falsePositives, isEmpty);
    });

    test('search synonyms never become artifact matches', () {
      for (final String query in <String>[
        'unix',
        'minify',
        'crontab',
        'UNIX',
      ]) {
        expect(UtilityCatalog.detectArtifacts(query), isEmpty, reason: query);
        expect(UtilityCatalog.searchByName(query), isNotEmpty, reason: query);
      }
    });
  });

  group('README coverage — drift guard', () {
    test('toolbox section names every catalog tool', () {
      final String readme = File('README.md').readAsStringSync();

      const String heading = 'in the toolbox today';
      final int start = readme.indexOf(heading);
      expect(
        start,
        isNonNegative,
        reason: 'README is missing the "$heading" section.',
      );

      // Scope the check to that section (up to the next "## " heading).
      final int next = readme.indexOf('\n## ', start);
      final String section = next == -1
          ? readme.substring(start)
          : readme.substring(start, next);

      final List<String> missing = <String>[
        for (final UtilityDescriptor u in UtilityCatalog.all)
          if (!section.contains(u.name)) u.name,
      ];

      expect(
        missing,
        isEmpty,
        reason:
            'README "toolbox today" section is missing: ${missing.join(', ')}. '
            'Add a bullet naming each (see lib/utility_catalog.dart).',
      );
    });
  });
}
