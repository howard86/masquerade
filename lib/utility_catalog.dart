import 'dart:convert';

import 'package:flutter/cupertino.dart';

import 'models/artifact.dart';
import 'state/link_group.dart';
import 'utils/bps_parser.dart';
import 'utils/bytes_parser.dart';
import 'utils/case_parser.dart';
import 'utils/color_parser.dart';
import 'utils/cron_nl_parser.dart';
import 'utils/cron_parser.dart';
import 'utils/csv_parser.dart';
import 'utils/encoding_parser.dart';
import 'utils/environment_config_inspector.dart';
import 'utils/hash_parser.dart';
import 'utils/ip_parser.dart';
import 'utils/json_parser.dart';
import 'utils/jwt_parser.dart';
import 'utils/math_parser.dart';
import 'utils/number_base_parser.dart';
import 'utils/toml_parser.dart';
import 'utils/timestamp_parser.dart';
import 'utils/uuid_parser.dart';
import 'utils/x509_inspector.dart';
import 'utils/yaml_parser.dart';
import 'widgets/mq/mq_icons.dart';
import 'widgets/mq/tool_action_bar.dart';
import 'widgets/tool_bodies/artifact_inspector_body.dart';
import 'widgets/tool_bodies/base64_body.dart';
import 'widgets/tool_bodies/bps_body.dart';
import 'widgets/tool_bodies/bytes_body.dart';
import 'widgets/tool_bodies/case_body.dart';
import 'widgets/tool_bodies/color_body.dart';
import 'widgets/tool_bodies/cron_body.dart';
import 'widgets/tool_bodies/csv_body.dart';
import 'widgets/tool_bodies/diff_body.dart';
import 'widgets/tool_bodies/environment_config_inspector_body.dart';
import 'widgets/tool_bodies/generator_body.dart';
import 'widgets/tool_bodies/hash_body.dart';
import 'widgets/tool_bodies/http_inspector_body.dart';
import 'widgets/tool_bodies/ip_body.dart';
import 'widgets/tool_bodies/json_body.dart';
import 'widgets/tool_bodies/jwt_body.dart';
import 'widgets/tool_bodies/list_body.dart';
import 'widgets/tool_bodies/log_stack_inspector_body.dart';
import 'widgets/tool_bodies/math_body.dart';
import 'widgets/tool_bodies/number_base_body.dart';
import 'widgets/tool_bodies/qr_code_body.dart';
import 'widgets/tool_bodies/regex_body.dart';
import 'widgets/tool_bodies/seed_source.dart';
import 'widgets/tool_bodies/timestamp_body.dart';
import 'widgets/tool_bodies/unicode_string_inspector_body.dart';
import 'widgets/tool_bodies/url_body.dart';
import 'widgets/tool_bodies/uuid_body.dart';
import 'widgets/tool_bodies/x509_inspector_body.dart';

/// Routes a cross-tool "Open in X" tap from any tool body's footer back to
/// the host screen, which expands the target tool's inline card seeded with
/// [input]. Fired by `OpenInFooter` and the QR scan-result chips.
typedef OpenInToolCallback = void Function(UtilityDescriptor u, String input);

typedef ArtifactDetector =
    List<DetectionMatch<Object?>> Function(
      String input,
      ArtifactProvenance provenance,
    );

/// Default on-canvas width for a tool's card in the desktop shell. Mobile
/// ignores this — every body is full-width there. Some tools earn more room
/// because their content needs it (Cron's 7-day strip, JSON's two panes,
/// Diff's dual panes); the user can still resize any card from its default.
enum CardWidthClass {
  /// 380 px — a hair wider than mobile's 340 px column. The default.
  standard(380),

  /// 560 px — for content with a horizontal strip or palette.
  wide(560),

  /// 640 px — for genuinely two-pane content.
  xwide(640);

  const CardWidthClass(this.px);

  /// Default card width in logical pixels.
  final double px;
}

enum UtilityCategory {
  inspect('Inspect'),
  transform('Transform'),
  generate('Generate'),
  compareValidate('Compare and validate'),
  all('All tools');

  const UtilityCategory(this.label);

  final String label;
}

enum UtilityInputSource { text, clipboard, camera, liveLink }

enum UtilityQuickAction { paste, copy, share, openIn, scan }

enum UtilitySensitivity { standard, sensitive }

enum HistoryPolicy { enabled, disabled }

/// Builds an embeddable tool body for inline rendering inside an
/// `InlineToolCard`. Receives the optional seed input and how it arrived
/// ([SeedSource]) so the body can decide whether to record history
/// immediately (paste) or behind a typing-debounce. [onSwitchTool] lets a
/// body pipe its current output into another tool without leaving Home.
/// When [actionBar] is non-null, the body should bind its paste/clear
/// handlers on the controller so the detail route can render a pinned bar.
/// [link] is non-null only when the body's card is in a desktop canvas Link
/// group (see docs/adr/0001); a linkable body then projects the group's
/// canonical value to its display and emits local edits back. It is always
/// null on mobile and Home, so the seam stays backward-compatible.
typedef UtilityBuilder =
    Widget Function(
      BuildContext context, {
      String? initialInput,
      Artifact<Object?>? initialArtifact,
      SeedSource seedSource,
      OpenInToolCallback? onSwitchTool,
      ToolActionBarController? actionBar,
      LinkChannel? link,
    });

class UtilityDescriptor {
  const UtilityDescriptor({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.tint,
    required this.synonyms,
    required this.categories,
    required this.acceptedTypes,
    required this.producedTypes,
    required this.sensitivity,
    required this.inputSources,
    required this.liveLinkTypes,
    required this.quickActions,
    required this.batchCapable,
    required this.historyPolicy,
    required this.builder,
    this.detectArtifact,
    this.defaultCardWidth = CardWidthClass.standard,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color tint;
  final List<String> synonyms;
  final Set<UtilityCategory> categories;
  final Set<ContentType> acceptedTypes;
  final Set<ContentType> producedTypes;
  final UtilitySensitivity sensitivity;
  final Set<UtilityInputSource> inputSources;
  final Set<ContentType> liveLinkTypes;
  final Set<UtilityQuickAction> quickActions;
  final bool batchCapable;
  final HistoryPolicy historyPolicy;
  final UtilityBuilder builder;
  final ArtifactDetector? detectArtifact;

  /// Width this tool's card opens at on the desktop canvas. Mobile ignores it.
  final CardWidthClass defaultCardWidth;

  String get metadataSummary {
    final String accepted = acceptedTypes.isEmpty
        ? 'none'
        : acceptedTypes.map((ContentType t) => t.name).join('/');
    final String produced = producedTypes
        .map((ContentType t) => t.name)
        .join('/');
    return '$accepted → $produced · ${historyPolicy == HistoryPolicy.enabled ? 'history' : 'no history'}';
  }
}

/// Static catalog of every utility shipped in the app.
class UtilityCatalog {
  const UtilityCatalog._();

  static final List<UtilityDescriptor> all = <UtilityDescriptor>[
    UtilityDescriptor(
      id: 'environment_config_inspector',
      name: 'Environment & Config Inspector',
      description: 'Normalize · compare · redact config',
      icon: MqIcons.setting,
      tint: const Color(0xFF059669),
      synonyms: <String>[
        'env',
        'dotenv',
        'properties',
        'headers',
        'configuration',
        'key value',
      ],
      categories: <UtilityCategory>{
        UtilityCategory.inspect,
        UtilityCategory.transform,
        UtilityCategory.compareValidate,
      },
      acceptedTypes: <ContentType>{ContentType.text, ContentType.lines},
      producedTypes: <ContentType>{
        ContentType.text,
        ContentType.lines,
        ContentType.json,
      },
      sensitivity: UtilitySensitivity.sensitive,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
      },
      liveLinkTypes: <ContentType>{},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
        UtilityQuickAction.openIn,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.disabled,
      defaultCardWidth: CardWidthClass.wide,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => EnvironmentConfigInspectorBody(
            initialInput: initialInput,
            initialArtifact: initialArtifact,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
      detectArtifact: _detectEnvironmentConfig,
    ),
    UtilityDescriptor(
      id: 'log_stack_inspector',
      name: 'Log & Stack Inspector',
      description: 'Group · search · redact logs',
      icon: MqIcons.list,
      tint: const Color(0xFFF97316),
      synonyms: <String>[
        'log',
        'stack trace',
        'exception',
        'jsonl',
        'ansi',
        'debug',
      ],
      categories: <UtilityCategory>{UtilityCategory.inspect},
      acceptedTypes: <ContentType>{ContentType.text, ContentType.lines},
      producedTypes: <ContentType>{ContentType.text, ContentType.lines},
      sensitivity: UtilitySensitivity.sensitive,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
      },
      liveLinkTypes: <ContentType>{},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
        UtilityQuickAction.share,
        UtilityQuickAction.openIn,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.disabled,
      defaultCardWidth: CardWidthClass.wide,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => LogStackInspectorBody(
            initialInput: initialInput,
            initialArtifact: initialArtifact,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
    ),
    UtilityDescriptor(
      id: 'unicode_string_inspector',
      name: 'Unicode Inspector',
      description: 'Reveal code points and hidden text',
      icon: MqIcons.textCase,
      tint: const Color(0xFF7C3AED),
      synonyms: <String>[
        'unicode',
        'string',
        'grapheme',
        'normalization',
        'invisible',
        'bidi',
        'confusable',
      ],
      categories: <UtilityCategory>{
        UtilityCategory.inspect,
        UtilityCategory.transform,
        UtilityCategory.compareValidate,
      },
      acceptedTypes: <ContentType>{ContentType.text},
      producedTypes: <ContentType>{ContentType.text, ContentType.bytes},
      sensitivity: UtilitySensitivity.sensitive,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
      },
      liveLinkTypes: <ContentType>{},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.openIn,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.disabled,
      defaultCardWidth: CardWidthClass.wide,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => UnicodeStringInspectorBody(
            initialInput: initialInput,
            initialArtifact: initialArtifact,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
    ),
    UtilityDescriptor(
      id: 'x509_inspector',
      name: 'X.509 Inspector',
      description: 'Inspect certificates and PEM chains',
      icon: MqIcons.shield,
      tint: const Color(0xFF2563EB),
      synonyms: <String>['x509', 'certificate', 'pem', 'der', 'tls', 'ssl'],
      categories: <UtilityCategory>{
        UtilityCategory.inspect,
        UtilityCategory.transform,
      },
      acceptedTypes: <ContentType>{ContentType.text, ContentType.bytes},
      producedTypes: <ContentType>{
        ContentType.text,
        ContentType.bytes,
        ContentType.epoch,
      },
      sensitivity: UtilitySensitivity.sensitive,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
      },
      liveLinkTypes: <ContentType>{},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
        UtilityQuickAction.openIn,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.disabled,
      defaultCardWidth: CardWidthClass.wide,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => X509InspectorBody(
            initialInput: initialInput,
            initialArtifact: initialArtifact,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
      detectArtifact: _detectX509,
    ),
    UtilityDescriptor(
      id: 'http_inspector',
      name: 'HTTP Inspector',
      description: 'Inspect · redact · convert requests',
      icon: MqIcons.network,
      tint: const Color(0xFF0EA5E9),
      synonyms: <String>['http', 'curl', 'fetch', 'axios', 'request', 'api'],
      categories: <UtilityCategory>{
        UtilityCategory.inspect,
        UtilityCategory.transform,
      },
      acceptedTypes: <ContentType>{ContentType.text},
      producedTypes: <ContentType>{ContentType.text, ContentType.json},
      sensitivity: UtilitySensitivity.sensitive,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
      },
      liveLinkTypes: <ContentType>{},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
        UtilityQuickAction.openIn,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.disabled,
      defaultCardWidth: CardWidthClass.wide,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => HttpInspectorBody(
            initialInput: initialInput,
            initialArtifact: initialArtifact,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
    ),
    UtilityDescriptor(
      id: 'artifact_inspector',
      name: 'Artifact Inspector',
      description: 'Trace nested encoded data',
      icon: MqIcons.bytes,
      tint: const Color(0xFF8B5CF6),
      synonyms: <String>['artifact', 'inspect', 'nested', 'decode', 'layers'],
      categories: <UtilityCategory>{UtilityCategory.inspect},
      acceptedTypes: <ContentType>{ContentType.text},
      producedTypes: <ContentType>{...ContentType.values},
      sensitivity: UtilitySensitivity.sensitive,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
      },
      liveLinkTypes: <ContentType>{},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.openIn,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.disabled,
      defaultCardWidth: CardWidthClass.wide,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => ArtifactInspectorBody(
            initialInput: initialInput,
            initialArtifact: initialArtifact,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
            link: link,
          ),
    ),
    UtilityDescriptor(
      id: 'uuid',
      name: 'UUID',
      description: 'Generate · validate · v4 / v7 / ULID',
      icon: MqIcons.uuid,
      tint: const Color(0xFF14B8A6),
      synonyms: <String>['uuid', 'guid', 'ulid', 'identifier'],
      categories: <UtilityCategory>{
        UtilityCategory.inspect,
        UtilityCategory.generate,
        UtilityCategory.compareValidate,
      },
      acceptedTypes: <ContentType>{ContentType.text},
      producedTypes: <ContentType>{ContentType.text},
      sensitivity: UtilitySensitivity.standard,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
      },
      liveLinkTypes: <ContentType>{},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
        UtilityQuickAction.openIn,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.enabled,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => UuidBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
            link: link,
          ),
      detectArtifact: _detectUuid,
    ),
    UtilityDescriptor(
      id: 'ip',
      name: 'IP / CIDR',
      description: 'IPv4 · IPv6 · subnet info',
      icon: MqIcons.network,
      tint: const Color(0xFF10B981),
      synonyms: <String>['ip', 'ipv4', 'ipv6', 'cidr', 'subnet', 'netmask'],
      categories: <UtilityCategory>{
        UtilityCategory.inspect,
        UtilityCategory.compareValidate,
      },
      acceptedTypes: <ContentType>{ContentType.text},
      producedTypes: <ContentType>{ContentType.text},
      sensitivity: UtilitySensitivity.standard,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
      },
      liveLinkTypes: <ContentType>{},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
        UtilityQuickAction.openIn,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.enabled,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => IpBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
            link: link,
          ),
      detectArtifact: _detectIp,
    ),
    UtilityDescriptor(
      id: 'number_base',
      name: 'Number Base',
      description: 'Hex · binary · octal · decimal',
      icon: MqIcons.binary,
      tint: const Color(0xFF3B6DD6),
      synonyms: <String>['hex', 'binary', 'octal', 'decimal', 'base'],
      categories: <UtilityCategory>{UtilityCategory.transform},
      acceptedTypes: <ContentType>{ContentType.number, ContentType.text},
      producedTypes: <ContentType>{ContentType.number, ContentType.text},
      sensitivity: UtilitySensitivity.standard,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
        UtilityInputSource.liveLink,
      },
      liveLinkTypes: <ContentType>{ContentType.number},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
        UtilityQuickAction.openIn,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.enabled,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => NumberBaseBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
            link: link,
          ),
      detectArtifact: _detectNumberBase,
    ),
    UtilityDescriptor(
      id: 'timestamp',
      name: 'Timestamp',
      description: 'Unix s/ms · ISO 8601',
      icon: MqIcons.clock,
      tint: const Color(0xFF00B8C4),
      synonyms: <String>['epoch', 'unix', 'iso', 'date', 'time'],
      categories: <UtilityCategory>{
        UtilityCategory.inspect,
        UtilityCategory.transform,
      },
      acceptedTypes: <ContentType>{
        ContentType.epoch,
        ContentType.number,
        ContentType.text,
      },
      producedTypes: <ContentType>{ContentType.epoch, ContentType.text},
      sensitivity: UtilitySensitivity.standard,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
        UtilityInputSource.liveLink,
      },
      liveLinkTypes: <ContentType>{ContentType.epoch, ContentType.number},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
        UtilityQuickAction.openIn,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.enabled,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => TimestampBody(
            initialInput: initialInput,
            initialArtifact: initialArtifact,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
            link: link,
          ),
      detectArtifact: _detectTimestamp,
    ),
    UtilityDescriptor(
      id: 'cron',
      name: 'Cron',
      description: 'Cron schedules and natural language',
      icon: MqIcons.cron,
      tint: const Color(0xFFD946EF),
      synonyms: <String>['cron', 'schedule', 'crontab'],
      categories: <UtilityCategory>{UtilityCategory.inspect},
      acceptedTypes: <ContentType>{ContentType.text},
      producedTypes: <ContentType>{ContentType.text},
      sensitivity: UtilitySensitivity.standard,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
      },
      liveLinkTypes: <ContentType>{},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
        UtilityQuickAction.openIn,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.enabled,
      defaultCardWidth: CardWidthClass.wide,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => CronBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
      detectArtifact: _detectCron,
    ),
    UtilityDescriptor(
      id: 'json',
      name: 'JSON / YAML / TOML',
      description: 'Convert · pretty · minify · tree',
      icon: MqIcons.brackets,
      tint: const Color(0xFF8B5CF6),
      synonyms: <String>[
        'pretty',
        'minify',
        'tree',
        'parse',
        'yaml',
        'yml',
        'toml',
        'config',
        'convert',
      ],
      categories: <UtilityCategory>{
        UtilityCategory.inspect,
        UtilityCategory.transform,
        UtilityCategory.compareValidate,
      },
      acceptedTypes: <ContentType>{ContentType.json, ContentType.text},
      producedTypes: <ContentType>{ContentType.json, ContentType.text},
      sensitivity: UtilitySensitivity.standard,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
        UtilityInputSource.liveLink,
      },
      liveLinkTypes: <ContentType>{ContentType.text},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
        UtilityQuickAction.openIn,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.enabled,
      defaultCardWidth: CardWidthClass.xwide,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => JSONBody(
            initialInput: initialInput,
            initialArtifact: initialArtifact,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
            link: link,
          ),
      detectArtifact: _detectStructured,
    ),
    UtilityDescriptor(
      id: 'csv',
      name: 'CSV / TSV',
      description: 'Tabular ↔ JSON · table view',
      icon: MqIcons.brackets,
      tint: const Color(0xFF84CC16),
      synonyms: <String>['csv', 'tsv', 'table', 'spreadsheet', 'rfc4180'],
      categories: <UtilityCategory>{
        UtilityCategory.inspect,
        UtilityCategory.transform,
      },
      acceptedTypes: <ContentType>{ContentType.text, ContentType.json},
      producedTypes: <ContentType>{ContentType.text, ContentType.json},
      sensitivity: UtilitySensitivity.standard,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
      },
      liveLinkTypes: <ContentType>{},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
        UtilityQuickAction.openIn,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.enabled,
      defaultCardWidth: CardWidthClass.xwide,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => CsvBody(
            initialInput: initialInput,
            initialArtifact: initialArtifact,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
      detectArtifact: _detectCsv,
    ),
    UtilityDescriptor(
      id: 'jwt',
      name: 'JWT',
      description: 'Decode header · payload · claims',
      icon: MqIcons.key,
      tint: const Color(0xFFA855F7),
      synonyms: <String>['jwt', 'token', 'jose', 'bearer', 'auth'],
      categories: <UtilityCategory>{
        UtilityCategory.inspect,
        UtilityCategory.compareValidate,
      },
      acceptedTypes: <ContentType>{ContentType.text},
      producedTypes: <ContentType>{ContentType.json, ContentType.text},
      sensitivity: UtilitySensitivity.sensitive,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
      },
      liveLinkTypes: <ContentType>{},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.disabled,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => JwtBody(
            initialInput: initialInput,
            initialArtifact: initialArtifact,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
      detectArtifact: _detectJwt,
    ),
    UtilityDescriptor(
      id: 'base64',
      name: 'Base64',
      description: 'Encode / decode · URL-safe',
      icon: MqIcons.textCase,
      tint: const Color(0xFF0EA5E9),
      synonyms: <String>['encode', 'decode', 'b64', 'url-safe'],
      categories: <UtilityCategory>{UtilityCategory.transform},
      acceptedTypes: <ContentType>{ContentType.text, ContentType.bytes},
      producedTypes: <ContentType>{ContentType.text, ContentType.bytes},
      sensitivity: UtilitySensitivity.standard,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
        UtilityInputSource.liveLink,
      },
      liveLinkTypes: <ContentType>{ContentType.text},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
        UtilityQuickAction.openIn,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.enabled,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => Base64Body(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
            link: link,
          ),
      detectArtifact: _detectBase64,
    ),
    UtilityDescriptor(
      id: 'case',
      name: 'Case',
      description: 'camel · snake · kebab · pascal · …',
      icon: MqIcons.textCase,
      tint: const Color(0xFFFACC15),
      synonyms: <String>[
        'case',
        'camel',
        'snake',
        'kebab',
        'pascal',
        'identifier',
        'naming',
      ],
      categories: <UtilityCategory>{UtilityCategory.transform},
      acceptedTypes: <ContentType>{ContentType.text},
      producedTypes: <ContentType>{ContentType.text},
      sensitivity: UtilitySensitivity.standard,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
      },
      liveLinkTypes: <ContentType>{},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
        UtilityQuickAction.openIn,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.enabled,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => CaseBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
      detectArtifact: _detectCase,
    ),
    UtilityDescriptor(
      id: 'url',
      name: 'URL',
      description: 'Percent encode / decode · query string',
      icon: MqIcons.globe,
      tint: const Color(0xFF06B6D4),
      synonyms: <String>[
        'url',
        'uri',
        'percent',
        'encode',
        'decode',
        'query',
        'querystring',
        'escape',
      ],
      categories: <UtilityCategory>{
        UtilityCategory.inspect,
        UtilityCategory.transform,
      },
      acceptedTypes: <ContentType>{ContentType.text},
      producedTypes: <ContentType>{ContentType.text},
      sensitivity: UtilitySensitivity.standard,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
      },
      liveLinkTypes: <ContentType>{},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
        UtilityQuickAction.openIn,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.enabled,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => UrlBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
            link: link,
          ),
      detectArtifact: _detectUrl,
    ),
    UtilityDescriptor(
      id: 'color',
      name: 'Color',
      description: 'HEX · RGB · HSL · OKLCH',
      icon: MqIcons.drop,
      tint: const Color(0xFFEC4899),
      synonyms: <String>['hex', 'rgb', 'hsl', 'oklch', 'contrast', 'wcag'],
      categories: <UtilityCategory>{
        UtilityCategory.inspect,
        UtilityCategory.transform,
        UtilityCategory.compareValidate,
      },
      acceptedTypes: <ContentType>{ContentType.color, ContentType.text},
      producedTypes: <ContentType>{ContentType.color, ContentType.text},
      sensitivity: UtilitySensitivity.standard,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
        UtilityInputSource.liveLink,
      },
      liveLinkTypes: <ContentType>{ContentType.color, ContentType.text},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
        UtilityQuickAction.openIn,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.enabled,
      defaultCardWidth: CardWidthClass.wide,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => ColorBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
            link: link,
          ),
      detectArtifact: _detectColor,
    ),
    UtilityDescriptor(
      id: 'math',
      name: 'Math',
      description: 'Expression evaluator · pi · sin · log',
      icon: MqIcons.calculator,
      tint: const Color(0xFFEF4444),
      synonyms: <String>[
        'calc',
        'calculator',
        'expression',
        'evaluate',
        'arithmetic',
      ],
      categories: <UtilityCategory>{UtilityCategory.transform},
      acceptedTypes: <ContentType>{
        ContentType.number,
        ContentType.epoch,
        ContentType.text,
      },
      producedTypes: <ContentType>{ContentType.number},
      sensitivity: UtilitySensitivity.standard,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
        UtilityInputSource.liveLink,
      },
      liveLinkTypes: <ContentType>{ContentType.number, ContentType.epoch},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
        UtilityQuickAction.openIn,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.enabled,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => MathBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
            link: link,
          ),
      detectArtifact: _detectMath,
    ),
    UtilityDescriptor(
      id: 'bps',
      name: 'bps · % · decimal',
      description: 'Basis points ↔ % ↔ decimal',
      icon: MqIcons.pct,
      tint: const Color(0xFFF59E0B),
      synonyms: <String>['basis points', 'percent', 'rate', 'finance'],
      categories: <UtilityCategory>{UtilityCategory.transform},
      acceptedTypes: <ContentType>{ContentType.number, ContentType.text},
      producedTypes: <ContentType>{ContentType.number},
      sensitivity: UtilitySensitivity.standard,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
      },
      liveLinkTypes: <ContentType>{},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
        UtilityQuickAction.openIn,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.enabled,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => BpsBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
      detectArtifact: _detectBps,
    ),
    UtilityDescriptor(
      id: 'bytes',
      name: 'Bytes',
      description: 'Byte array ↔ text (UTF-8)',
      icon: MqIcons.bytes,
      tint: const Color(0xFF22C55E),
      synonyms: <String>['buffer', 'bytes', 'array', 'utf8', 'utf-8', 'decode'],
      categories: <UtilityCategory>{
        UtilityCategory.inspect,
        UtilityCategory.transform,
      },
      acceptedTypes: <ContentType>{ContentType.bytes, ContentType.text},
      producedTypes: <ContentType>{ContentType.bytes, ContentType.text},
      sensitivity: UtilitySensitivity.standard,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
      },
      liveLinkTypes: <ContentType>{},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
        UtilityQuickAction.openIn,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.enabled,
      defaultCardWidth: CardWidthClass.wide,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => BytesBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
      detectArtifact: _detectBytes,
    ),
    UtilityDescriptor(
      id: 'list',
      name: 'List',
      description: 'Split ↔ join · separators',
      icon: MqIcons.list,
      tint: const Color(0xFF84CC16),
      synonyms: <String>[
        'split',
        'join',
        'delimiter',
        'separator',
        'csv',
        'comma',
        'lines',
      ],
      categories: <UtilityCategory>{UtilityCategory.transform},
      acceptedTypes: <ContentType>{ContentType.lines, ContentType.text},
      producedTypes: <ContentType>{ContentType.lines, ContentType.text},
      sensitivity: UtilitySensitivity.standard,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
        UtilityInputSource.liveLink,
      },
      liveLinkTypes: <ContentType>{ContentType.lines, ContentType.text},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
        UtilityQuickAction.openIn,
      },
      batchCapable: true,
      historyPolicy: HistoryPolicy.enabled,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => ListToolBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
            link: link,
          ),
      detectArtifact: _detectList,
    ),
    UtilityDescriptor(
      id: 'regex',
      name: 'Regex',
      description: 'Test patterns · captures',
      icon: MqIcons.brackets,
      tint: const Color(0xFFEC4899),
      synonyms: <String>['regex', 'regexp', 'pattern', 'match', 'capture'],
      categories: <UtilityCategory>{
        UtilityCategory.inspect,
        UtilityCategory.compareValidate,
      },
      acceptedTypes: <ContentType>{ContentType.text},
      producedTypes: <ContentType>{ContentType.text},
      sensitivity: UtilitySensitivity.standard,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
      },
      liveLinkTypes: <ContentType>{},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.enabled,
      defaultCardWidth: CardWidthClass.wide,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => RegexBody(
            initialInput: initialInput,
            seedSource: seedSource,
            actionBar: actionBar,
          ),
      detectArtifact: _detectRegex,
    ),
    UtilityDescriptor(
      id: 'diff',
      name: 'Diff',
      description: 'Compare two texts · line / word',
      icon: MqIcons.diff,
      tint: const Color(0xFF64748B),
      synonyms: <String>['diff', 'compare', 'changes', 'patch', 'difference'],
      categories: <UtilityCategory>{UtilityCategory.compareValidate},
      acceptedTypes: <ContentType>{ContentType.lines, ContentType.text},
      producedTypes: <ContentType>{ContentType.lines, ContentType.text},
      sensitivity: UtilitySensitivity.standard,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
        UtilityInputSource.liveLink,
      },
      liveLinkTypes: <ContentType>{ContentType.text, ContentType.lines},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.enabled,
      defaultCardWidth: CardWidthClass.xwide,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => DiffBody(
            initialInput: initialInput,
            seedSource: seedSource,
            actionBar: actionBar,
            link: link,
          ),
    ),
    UtilityDescriptor(
      id: 'hash',
      name: 'Hash',
      description: 'MD5 · SHA-1 · SHA-256 · SHA-512',
      icon: MqIcons.hash,
      tint: const Color(0xFF0D9488),
      synonyms: <String>[
        'hash',
        'digest',
        'md5',
        'sha',
        'checksum',
        'fingerprint',
      ],
      categories: <UtilityCategory>{
        UtilityCategory.generate,
        UtilityCategory.compareValidate,
      },
      acceptedTypes: <ContentType>{ContentType.bytes, ContentType.text},
      producedTypes: <ContentType>{ContentType.text},
      sensitivity: UtilitySensitivity.standard,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
      },
      liveLinkTypes: <ContentType>{},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
        UtilityQuickAction.openIn,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.enabled,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => HashBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
      detectArtifact: _detectHashAndPem,
    ),
    UtilityDescriptor(
      id: 'qr_code',
      name: 'QR Code',
      description: 'Scan · generate QR',
      icon: MqIcons.qrCode,
      tint: const Color(0xFF6366F1),
      synonyms: <String>['qr', 'barcode', 'scan', 'generate'],
      categories: <UtilityCategory>{
        UtilityCategory.inspect,
        UtilityCategory.generate,
      },
      acceptedTypes: <ContentType>{ContentType.text},
      producedTypes: <ContentType>{ContentType.text},
      sensitivity: UtilitySensitivity.standard,
      inputSources: <UtilityInputSource>{
        UtilityInputSource.text,
        UtilityInputSource.clipboard,
        UtilityInputSource.camera,
      },
      liveLinkTypes: <ContentType>{},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.paste,
        UtilityQuickAction.copy,
        UtilityQuickAction.share,
        UtilityQuickAction.openIn,
        UtilityQuickAction.scan,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.enabled,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => QrCodeBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
    ),
    UtilityDescriptor(
      id: 'generator',
      name: 'Generator',
      description: 'Password · token · UUID',
      icon: MqIcons.dices,
      tint: const Color(0xFFF97316),
      synonyms: <String>[
        'generate',
        'random',
        'password',
        'token',
        'secret',
        'key',
        'nonce',
        'salt',
      ],
      categories: <UtilityCategory>{UtilityCategory.generate},
      acceptedTypes: <ContentType>{},
      producedTypes: <ContentType>{ContentType.text},
      sensitivity: UtilitySensitivity.sensitive,
      inputSources: <UtilityInputSource>{},
      liveLinkTypes: <ContentType>{},
      quickActions: <UtilityQuickAction>{
        UtilityQuickAction.copy,
        UtilityQuickAction.openIn,
      },
      batchCapable: false,
      historyPolicy: HistoryPolicy.disabled,
      builder:
          (
            BuildContext _, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) => GeneratorBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
            link: link,
          ),
    ),
  ];

  static UtilityDescriptor byId(String id) =>
      all.firstWhere((UtilityDescriptor u) => u.id == id);

  /// Like [byId] but returns null instead of throwing — for restoring a saved
  /// canvas whose tool id may no longer exist in the catalog.
  static UtilityDescriptor? byIdOrNull(String id) {
    for (final UtilityDescriptor u in all) {
      if (u.id == id) return u;
    }
    return null;
  }

  static List<UtilityDescriptor> inCategory(UtilityCategory category) =>
      List<UtilityDescriptor>.unmodifiable(
        category == UtilityCategory.all
            ? all
            : all.where(
                (UtilityDescriptor u) => u.categories.contains(category),
              ),
      );

  /// Name/synonym search that keeps catalog-relative order for the Library.
  static List<UtilityDescriptor> searchStable(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return List<UtilityDescriptor>.unmodifiable(all);
    return List<UtilityDescriptor>.unmodifiable(
      all.where((UtilityDescriptor u) => _scoreTool(u, q) > 0),
    );
  }

  /// Ranks the catalog by name/synonym match for the command palette's
  /// free-text query. Unlike [detectArtifacts], this never inspects input
  /// *shape* —
  /// it's a pure name search. An empty query returns the full catalog in
  /// catalog order so the palette shows everything before the user types.
  static List<UtilityDescriptor> searchByName(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return List<UtilityDescriptor>.unmodifiable(all);
    final List<({UtilityDescriptor u, int score})> ranked =
        <({UtilityDescriptor u, int score})>[];
    for (final UtilityDescriptor u in all) {
      final int s = _scoreTool(u, q);
      if (s > 0) ranked.add((u: u, score: s));
    }
    ranked.sort(
      (
        ({UtilityDescriptor u, int score}) a,
        ({UtilityDescriptor u, int score}) b,
      ) => b.score.compareTo(a.score),
    );
    return ranked
        .map((({UtilityDescriptor u, int score}) e) => e.u)
        .toList(growable: false);
  }

  /// Detects artifact interpretations independently from name search.
  static List<DetectionMatch<Object?>> detectArtifacts(
    String input, {
    ArtifactProvenance provenance = ArtifactProvenance.typed,
  }) {
    if (input.trim().isEmpty) return const <DetectionMatch<Object?>>[];
    final List<DetectionMatch<Object?>> matches = <DetectionMatch<Object?>>[
      for (final UtilityDescriptor tool in all)
        ...?tool.detectArtifact?.call(input, provenance),
    ];
    matches.sort((DetectionMatch<Object?> a, DetectionMatch<Object?> b) {
      final int confidence = b.confidence.compareTo(a.confidence);
      if (confidence != 0) return confidence;
      final int primary = _catalogIndex(
        a.primaryToolId,
      ).compareTo(_catalogIndex(b.primaryToolId));
      if (primary != 0) return primary;
      return a.artifact.kind.index.compareTo(b.artifact.kind.index);
    });

    final Set<(ArtifactKind, String)> seen = <(ArtifactKind, String)>{};
    return List<DetectionMatch<Object?>>.unmodifiable(
      matches.where(
        (DetectionMatch<Object?> match) =>
            seen.add((match.artifact.kind, match.primaryToolId)),
      ),
    );
  }

  /// Resolves one interpretation's primary tool, then compatible alternates.
  static List<UtilityDescriptor> toolsFor(DetectionMatch<Object?> match) =>
      List<UtilityDescriptor>.unmodifiable(<UtilityDescriptor>[
        byId(match.primaryToolId),
        for (final UtilityDescriptor tool in all)
          if (tool.id != match.primaryToolId &&
              match.compatibleToolIds.contains(tool.id))
            tool,
      ]);

  /// Flattens ranked interpretations without suggesting a tool twice.
  static List<UtilityDescriptor> detectedTools(
    Iterable<DetectionMatch<Object?>> matches,
  ) {
    final Set<String> seen = <String>{};
    return List<UtilityDescriptor>.unmodifiable(<UtilityDescriptor>[
      for (final DetectionMatch<Object?> match in matches)
        for (final UtilityDescriptor tool in toolsFor(match))
          if (seen.add(tool.id)) tool,
    ]);
  }

  /// Shape-compatible tools that can consume output from [sourceUtilityId].
  /// Unknown sources fail closed rather than bypassing typed routing.
  static List<UtilityDescriptor> compatibleNextSteps(
    String sourceUtilityId,
    String output, {
    List<DetectionMatch<Object?>> Function(List<DetectionMatch<Object?>>)? rank,
  }) {
    final UtilityDescriptor? source = byIdOrNull(sourceUtilityId);
    if (source == null) return const <UtilityDescriptor>[];
    final List<DetectionMatch<Object?>> matches = detectArtifacts(
      output,
      provenance: ArtifactProvenance.generated,
    );
    return detectedTools(rank?.call(matches) ?? matches)
        .where(
          (UtilityDescriptor target) =>
              source.producedTypes.any(target.acceptedTypes.contains),
        )
        .toList(growable: false);
  }

  static int _catalogIndex(String id) =>
      all.indexWhere((UtilityDescriptor tool) => tool.id == id);

  static int _scoreTool(UtilityDescriptor u, String q) {
    final String name = u.name.toLowerCase();
    if (name == q) return 100;
    for (final String syn in u.synonyms) {
      if (syn.toLowerCase() == q) return 90;
    }
    if (name.startsWith(q)) return 70;
    for (final String syn in u.synonyms) {
      if (syn.toLowerCase().startsWith(q)) return 60;
    }
    if (name.contains(q)) return 40;
    for (final String syn in u.synonyms) {
      if (syn.toLowerCase().contains(q)) return 30;
    }
    return 0;
  }
}

List<DetectionMatch<Object?>> _detectRegex(String _, ArtifactProvenance _) =>
    const <DetectionMatch<Object?>>[];

final RegExp _ipv4Cidr = RegExp(r'^(\d{1,3}\.){3}\d{1,3}(/\d{1,2})?$');
final RegExp _ipv6Cidr = RegExp(r'^[0-9A-Fa-f:]+(/\d{1,3})?$');

final RegExp _uuidDashed = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final RegExp _uuidPlain = RegExp(r'^[0-9a-fA-F]{32}$');
final RegExp _ulidShape = RegExp(r'^[0-9A-HJKMNP-TV-Za-hjkmnp-tv-z]{26}$');

DetectionMatch<Object?> _evidence({
  required ArtifactProvenance provenance,
  required ArtifactKind kind,
  required String rawValue,
  required Object? parserResult,
  required double confidence,
  required String reason,
  required String primaryToolId,
  Set<String>? compatibleToolIds,
}) => DetectionMatch<Object?>(
  artifact: Artifact<Object?>(
    kind: kind,
    rawValue: rawValue,
    provenance: provenance,
    parserResult: parserResult,
  ),
  confidence: confidence,
  reason: reason,
  primaryToolId: primaryToolId,
  compatibleToolIds: compatibleToolIds ?? <String>{primaryToolId},
);

List<DetectionMatch<Object?>> _detectUuid(
  String input,
  ArtifactProvenance provenance,
) {
  final String t = input.trim();
  if (!_uuidDashed.hasMatch(t) &&
      !_uuidPlain.hasMatch(t) &&
      !_ulidShape.hasMatch(t)) {
    return const <DetectionMatch<Object?>>[];
  }
  final UuidParseResult r = UuidParser.parse(t);
  if (r is! UuidOk && r is! UlidOk) {
    return const <DetectionMatch<Object?>>[];
  }
  return <DetectionMatch<Object?>>[
    _evidence(
      provenance: provenance,
      kind: ArtifactKind.uuid,
      rawValue: input,
      parserResult: r,
      confidence: .98,
      reason: r is UlidOk
          ? '26 Crockford Base32 characters decoded as a ULID.'
          : 'Canonical UUID structure and version bits parsed successfully.',
      primaryToolId: 'uuid',
    ),
  ];
}

List<DetectionMatch<Object?>> _detectIp(
  String input,
  ArtifactProvenance provenance,
) {
  final String t = input.trim();
  if (!_ipv4Cidr.hasMatch(t) && !(t.contains(':') && _ipv6Cidr.hasMatch(t))) {
    return const <DetectionMatch<Object?>>[];
  }
  final IpParseResult result = IpParser.parse(t);
  if (result is! IpOk) return const <DetectionMatch<Object?>>[];
  return <DetectionMatch<Object?>>[
    _evidence(
      provenance: provenance,
      kind: ArtifactKind.ip,
      rawValue: input,
      parserResult: result,
      confidence: .98,
      reason: result.family == IpFamily.v4
          ? 'Parsed as a valid IPv4 address${result.prefix == null ? '' : ' and CIDR prefix'}.'
          : 'Parsed as a valid IPv6 address${result.prefix == null ? '' : ' and CIDR prefix'}.',
      primaryToolId: 'ip',
    ),
  ];
}

List<DetectionMatch<Object?>> _detectStructured(
  String input,
  ArtifactProvenance provenance,
) {
  final String t = input.trim();
  if (t.isEmpty) return const <DetectionMatch<Object?>>[];
  // Cheap pre-guard: structured input must carry at least one shape glyph.
  // Bypasses the regex sweep for plain scalars like "42", "deadbeef", words.
  if (!t.contains(':') &&
      !t.contains('=') &&
      !t.startsWith('[') &&
      !t.startsWith('{') &&
      !t.startsWith('---')) {
    return const <DetectionMatch<Object?>>[];
  }
  // `{...}` is JSON only. `[name]\n...` is a TOML table header — must be
  // matched before JSON-array since both start with `[`.
  if (t.startsWith('{') || (t.startsWith('[') && !TomlParser.looksLike(t))) {
    final JSONParseResult result = JSONParser.parse(t);
    if (result is! JSONOk) return const <DetectionMatch<Object?>>[];
    return <DetectionMatch<Object?>>[
      _evidence(
        provenance: provenance,
        kind: ArtifactKind.json,
        rawValue: input,
        parserResult: result,
        confidence: .97,
        reason: 'JSON syntax parsed successfully.',
        primaryToolId: 'json',
      ),
    ];
  }
  if (TomlParser.looksLike(t)) {
    final TomlParseResult result = TomlParser.parse(t);
    if (result is! TomlOk) return const <DetectionMatch<Object?>>[];
    return <DetectionMatch<Object?>>[
      _evidence(
        provenance: provenance,
        kind: ArtifactKind.toml,
        rawValue: input,
        parserResult: result,
        confidence: .91,
        reason: 'TOML table or key-value structure parsed successfully.',
        primaryToolId: 'json',
      ),
    ];
  }
  if (!YamlParser.looksLike(t)) return const <DetectionMatch<Object?>>[];
  final YamlParseResult result = YamlParser.parse(t);
  if (result is! YamlOk) return const <DetectionMatch<Object?>>[];
  return <DetectionMatch<Object?>>[
    _evidence(
      provenance: provenance,
      kind: ArtifactKind.yaml,
      rawValue: input,
      parserResult: result,
      confidence: .88,
      reason: 'YAML document structure parsed successfully.',
      primaryToolId: 'json',
    ),
  ];
}

List<DetectionMatch<Object?>> _detectCsv(
  String input,
  ArtifactProvenance provenance,
) {
  final String trimmed = input.trim();
  if (trimmed.isEmpty || trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return const <DetectionMatch<Object?>>[];
  }
  final CsvParseResult result = CsvParser.parse(input);
  if (result is! CsvOk) return const <DetectionMatch<Object?>>[];
  final int columns =
      result.header?.length ??
      (result.rows.isEmpty ? 0 : result.rows.first.length);
  final int records = result.rows.length + (result.hasHeader ? 1 : 0);
  if (columns < 2 || records < 2) {
    return const <DetectionMatch<Object?>>[];
  }
  final bool typedSignal = result.rows
      .expand((List<String> row) => row)
      .any((String cell) => num.tryParse(cell) != null);
  if (!result.hasHeader) {
    if (!typedSignal) return const <DetectionMatch<Object?>>[];
    final Iterable<String> firstColumn = result.rows.map(
      (List<String> row) => row.first.trim(),
    );
    const Set<String> logLevels = <String>{
      'TRACE',
      'DEBUG',
      'INFO',
      'WARN',
      'WARNING',
      'ERROR',
      'FATAL',
    };
    if (firstColumn.every(
          (String cell) => logLevels.contains(cell.toUpperCase()),
        ) ||
        firstColumn.every(
          (String cell) =>
              cell.startsWith('http://') || cell.startsWith('https://'),
        ) ||
        firstColumn.every((String cell) => cell.contains('='))) {
      return const <DetectionMatch<Object?>>[];
    }
  }
  return <DetectionMatch<Object?>>[
    _evidence(
      provenance: provenance,
      kind: ArtifactKind.unknown,
      rawValue: input,
      parserResult: result,
      confidence: .89,
      reason:
          'Parsed $records consistent rows with $columns columns using ${result.delimiter == '\t' ? 'a tab' : '“${result.delimiter}”'}.',
      primaryToolId: 'csv',
    ),
  ];
}

List<DetectionMatch<Object?>> _detectColor(
  String input,
  ArtifactProvenance provenance,
) {
  final String t = input.trim();
  if (t.isEmpty) return const <DetectionMatch<Object?>>[];
  // Reject base-prefixed numbers — those should fire Number Base only.
  final String lower = t.toLowerCase();
  if (lower.startsWith('0x') ||
      lower.startsWith('0b') ||
      lower.startsWith('0o')) {
    return const <DetectionMatch<Object?>>[];
  }
  final MqColorValue? result = MqColorParser.parse(t);
  if (result == null) return const <DetectionMatch<Object?>>[];
  return <DetectionMatch<Object?>>[
    _evidence(
      provenance: provenance,
      kind: ArtifactKind.color,
      rawValue: input,
      parserResult: result,
      confidence: t.startsWith('#') || t.contains('(') ? .96 : .72,
      reason: 'Parsed as a supported HEX, RGB, or HSL color.',
      primaryToolId: 'color',
    ),
  ];
}

List<DetectionMatch<Object?>> _detectTimestamp(
  String input,
  ArtifactProvenance provenance,
) {
  final String t = input.trim();
  if (t.isEmpty) return const <DetectionMatch<Object?>>[];
  // Accept only the unambiguous direct forms here; defer base64/hex variants
  // to their own tools to avoid double-counting.
  final int? n = int.tryParse(t);
  if (n != null) {
    // Reject obviously-tiny numbers that are noise (e.g. "1", "42").
    if (n.abs() < 100000000) return const <DetectionMatch<Object?>>[];
  }
  final TimestampParseResult result = TimestampParser.parseAnyFormat(t);
  if (!result.isSuccess) return const <DetectionMatch<Object?>>[];
  final bool decimalAmbiguity =
      n != null && t.replaceFirst('-', '').length == 10;
  final List<DetectionMatch<Object?>> matches = <DetectionMatch<Object?>>[
    _evidence(
      provenance: provenance,
      kind: ArtifactKind.timestamp,
      rawValue: input,
      parserResult: result,
      confidence: decimalAmbiguity ? .82 : .96,
      reason: decimalAmbiguity
          ? 'A 10-digit decimal is plausibly Unix seconds, but it may be an ordinary number.'
          : 'Parsed as ${result.format == TimestampFormat.iso8601 ? 'an ISO 8601 date-time' : 'a Unix timestamp'}.',
      primaryToolId: 'timestamp',
    ),
  ];
  if (n != null) {
    final NumberBaseParseResult number = NumberBaseParser.parse(t);
    if (number is NumberBaseOk) {
      matches.add(
        _evidence(
          provenance: provenance,
          kind: ArtifactKind.number,
          rawValue: input,
          parserResult: number,
          confidence: decimalAmbiguity ? .62 : .58,
          reason: decimalAmbiguity
              ? 'The same 10-digit value is also a plain decimal number; Timestamp is ranked first.'
              : 'The timestamp token is also a valid decimal integer.',
          primaryToolId: 'number_base',
        ),
      );
    }
  }
  return matches;
}

List<DetectionMatch<Object?>> _detectNumberBase(
  String input,
  ArtifactProvenance provenance,
) {
  final String t = input.trim();
  final NumberBaseParseResult result = NumberBaseParser.parse(t);
  if (result is! NumberBaseOk) return const <DetectionMatch<Object?>>[];
  final int? integer = int.tryParse(t);
  if (integer != null && integer.abs() >= 100000000) {
    final TimestampParseResult timestamp = TimestampParser.parseAnyFormat(t);
    if (timestamp.isSuccess) return const <DetectionMatch<Object?>>[];
  }
  return <DetectionMatch<Object?>>[
    _evidence(
      provenance: provenance,
      kind: ArtifactKind.number,
      rawValue: input,
      parserResult: result,
      confidence: t.toLowerCase().startsWith(RegExp(r'0[xbo]')) ? .96 : .72,
      reason: 'Parsed as a ${result.result.detectedBase}-base number.',
      primaryToolId: 'number_base',
    ),
  ];
}

List<DetectionMatch<Object?>> _detectCron(
  String input,
  ArtifactProvenance provenance,
) {
  final String t = input.trim();
  if (t.isEmpty) return const <DetectionMatch<Object?>>[];
  final CronParseResult syntax = CronParser.parseSyntax(t);
  final CronParseResult result = syntax.isSuccess
      ? syntax
      : CronNlParser.parse(t);
  if (!result.isSuccess) return const <DetectionMatch<Object?>>[];
  return <DetectionMatch<Object?>>[
    _evidence(
      provenance: provenance,
      kind: ArtifactKind.cron,
      rawValue: input,
      parserResult: result,
      confidence: syntax.isSuccess ? .97 : .86,
      reason: syntax.isSuccess
          ? 'Parsed as a valid cron schedule.'
          : 'Parsed as a supported natural-language schedule.',
      primaryToolId: 'cron',
    ),
  ];
}

final RegExp _jwtShape = RegExp(
  r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*$',
);

List<DetectionMatch<Object?>> _detectJwt(
  String input,
  ArtifactProvenance provenance,
) {
  final String t = input.trim();
  if (!_jwtShape.hasMatch(t)) return const <DetectionMatch<Object?>>[];
  final JwtParseResult result = JwtParser.parse(t);
  if (result is! JwtOk) return const <DetectionMatch<Object?>>[];
  final String headerSegment = t.split('.').first;
  return <DetectionMatch<Object?>>[
    _evidence(
      provenance: provenance,
      kind: ArtifactKind.jwt,
      rawValue: input,
      parserResult: result,
      confidence: .995,
      reason:
          'Three Base64URL segments decoded as JSON JWT header and payload.',
      primaryToolId: 'jwt',
    ),
    _evidence(
      provenance: provenance,
      kind: ArtifactKind.base64,
      rawValue: headerSegment,
      parserResult: EncodingResult(
        type: EncodingType.base64,
        result: jsonEncode(result.header),
        original: headerSegment,
      ),
      confidence: .74,
      reason: 'The JWT header is also Base64URL-encoded text.',
      primaryToolId: 'base64',
    ),
  ];
}

List<DetectionMatch<Object?>> _detectBase64(
  String input,
  ArtifactProvenance provenance,
) {
  final String t = input.trim();
  if (t.isEmpty) return const <DetectionMatch<Object?>>[];
  if (!EncodingParser.isBase64(t)) return const <DetectionMatch<Object?>>[];
  // Reject pure hex (those already fire Number Base / Color); require either
  // padding, or chars outside the hex alphabet.
  final bool isHexAlphabet = RegExp(r'^[0-9a-fA-F]+$').hasMatch(t);
  if (isHexAlphabet && !t.contains('=')) {
    return const <DetectionMatch<Object?>>[];
  }
  // Four unpadded letters are indistinguishable from ordinary words (for
  // example, the catalog name `List`). Short Base64 needs explicit padding.
  if (t.length < 8 && !t.contains('=')) {
    return const <DetectionMatch<Object?>>[];
  }
  // Reject inputs where the decoded bytes are not printable text — those tend
  // to be coincidental matches like a 4-char alphanumeric token.
  try {
    final List<int> bytes = (const Base64Decoder()).convert(t);
    if (bytes.isEmpty || !bytes.every(_isPrintableByte)) {
      return const <DetectionMatch<Object?>>[];
    }
    final EncodingResult result = EncodingResult(
      type: EncodingType.base64,
      result: utf8.decode(bytes),
      original: t,
    );
    return <DetectionMatch<Object?>>[
      _evidence(
        provenance: provenance,
        kind: ArtifactKind.base64,
        rawValue: input,
        parserResult: result,
        confidence: .9,
        reason: 'Valid Base64 decoded to printable text.',
        primaryToolId: 'base64',
      ),
    ];
  } catch (_) {
    return const <DetectionMatch<Object?>>[];
  }
}

final RegExp _identifierShape = RegExp(r'^[A-Za-z][A-Za-z0-9_\- .]*$');
final RegExp _caseSignal = RegExp(r'[_\-]|[a-z][A-Z]');

List<DetectionMatch<Object?>> _detectCase(
  String input,
  ArtifactProvenance provenance,
) {
  final String t = input.trim();
  if (t.isEmpty || t.length > 200) {
    return const <DetectionMatch<Object?>>[];
  }
  if (!_identifierShape.hasMatch(t) || !_caseSignal.hasMatch(t)) {
    return const <DetectionMatch<Object?>>[];
  }
  if (_detectJwt(input, provenance).isNotEmpty ||
      _detectUuid(input, provenance).isNotEmpty ||
      _detectBase64(input, provenance).isNotEmpty ||
      _detectHash(input, provenance).isNotEmpty) {
    return const <DetectionMatch<Object?>>[];
  }
  final CaseConversions? result = CaseParser.parse(t);
  if (result == null) return const <DetectionMatch<Object?>>[];
  return <DetectionMatch<Object?>>[
    _evidence(
      provenance: provenance,
      kind: ArtifactKind.unknown,
      rawValue: input,
      parserResult: result,
      confidence: .7,
      reason: 'Identifier separators or letter-case boundaries were found.',
      primaryToolId: 'case',
    ),
  ];
}

bool _isPrintableByte(int b) =>
    b == 0x09 || b == 0x0A || b == 0x0D || (b >= 0x20 && b <= 0x7E);

// A `%XX` percent-encoding run — the clearest URL-encoded signal.
final RegExp _percentEscape = RegExp(r'%[0-9A-Fa-f]{2}');
// A query string carrying ≥2 `key=value` pairs joined by `&`, or any pair
// behind a leading `?`. Narrow on purpose so it never poaches a single
// `KEY = value` env line (owned by JSON/TOML) or a bare `0.25%`.
final RegExp _queryShapeUrl = RegExp(r'^[^\s?#&=]*\?[^\s]*=[^\s]*$');
final RegExp _kvPair = RegExp(r'^[^\s&=]+=[^\s&]*$');

List<DetectionMatch<Object?>> _detectUrl(
  String input,
  ArtifactProvenance provenance,
) {
  final String t = input.trim();
  if (t.isEmpty) return const <DetectionMatch<Object?>>[];
  bool matches = _percentEscape.hasMatch(t) || _queryShapeUrl.hasMatch(t);
  // Bare `a=b&c=d`: every `&`-segment must be a clean key=value pair, and there
  // must be at least two — a single `k=v` is too ambiguous to claim.
  if (t.contains('&') && !t.contains(' ')) {
    final List<String> parts = t.split('&');
    matches = matches || (parts.length >= 2 && parts.every(_kvPair.hasMatch));
  }
  if (!matches) return const <DetectionMatch<Object?>>[];
  return <DetectionMatch<Object?>>[
    _evidence(
      provenance: provenance,
      kind: ArtifactKind.url,
      rawValue: input,
      parserResult: Uri.tryParse(t),
      confidence: _percentEscape.hasMatch(t) ? .91 : .86,
      reason: _percentEscape.hasMatch(t)
          ? 'Contains valid percent-encoded URL bytes.'
          : 'Contains a valid URL query-string shape.',
      primaryToolId: 'url',
    ),
  ];
}

List<DetectionMatch<Object?>> _detectBps(
  String input,
  ArtifactProvenance provenance,
) {
  final String t = input.trim().toLowerCase();
  if (t.isEmpty) return const <DetectionMatch<Object?>>[];
  final BpsResult? result = BpsParser.parse(t);
  if (result == null) return const <DetectionMatch<Object?>>[];
  // Without an explicit suffix, only suggest bps for small decimals (≤ 1).
  // Plain large integers like a unix timestamp shouldn't trigger this chip.
  final bool hasSuffix =
      t.endsWith('bps') || t.endsWith('bp') || t.endsWith('%');
  bool matches = hasSuffix;
  final double? n = double.tryParse(t);
  matches = matches || (n != null && n.abs() <= 1.0);
  if (!matches) return const <DetectionMatch<Object?>>[];
  return <DetectionMatch<Object?>>[
    _evidence(
      provenance: provenance,
      kind: ArtifactKind.bps,
      rawValue: input,
      parserResult: result,
      confidence: hasSuffix ? .95 : .72,
      reason: hasSuffix
          ? 'Explicit basis-point or percent suffix parsed successfully.'
          : 'Small decimal is plausibly a rate expressed as a fraction.',
      primaryToolId: 'bps',
    ),
  ];
}

List<DetectionMatch<Object?>> _detectHash(
  String input,
  ArtifactProvenance provenance,
) {
  final String t = input.trim();
  final HashIdentifyResult result = HashTool.identify(t);
  if (result is! HashShape) return const <DetectionMatch<Object?>>[];
  return <DetectionMatch<Object?>>[
    _evidence(
      provenance: provenance,
      kind: ArtifactKind.hash,
      rawValue: input,
      parserResult: result,
      confidence: .9,
      reason:
          '${result.hex.length} hexadecimal characters match ${result.name}.',
      primaryToolId: 'hash',
    ),
  ];
}

// Operator must sit between two *operand-shaped* tokens. Eliminates false
// positives like `0.5%` (unary-suffix percent) and `hsl(184, 100%, 38%)`
// (commas/parens flank the `%`).
final RegExp _mathBinaryOp = RegExp(
  r'[\dA-Za-z_)]\s*[+\-*/%^]\s*[\dA-Za-z_(\-]',
);

// ISO 8601 dates share the `-` character with subtraction; the timestamp tool
// owns these, so skip math detection when the input matches that shape.
final RegExp _isoDateShape = RegExp(r'^\d{4}-\d{2}-\d{2}([T ].*)?$');

final RegExp _mathIdent = RegExp(r'[A-Za-z_]+');

const Set<String> _mathFunctions = <String>{
  'sin',
  'cos',
  'tan',
  'asin',
  'acos',
  'atan',
  'log',
  'ln',
  'sqrt',
  'abs',
  'floor',
  'ceil',
  'round',
  'min',
  'max',
};
const Set<String> _mathConsts = <String>{'pi', 'e', 'ans'};

List<DetectionMatch<Object?>> _detectMath(
  String input,
  ArtifactProvenance provenance,
) {
  final String t = input.trim();
  if (t.isEmpty) return const <DetectionMatch<Object?>>[];
  if (_isoDateShape.hasMatch(t)) return const <DetectionMatch<Object?>>[];
  // A bulleted/numbered list reads as subtraction across line breaks
  // (`…T\n- E…`); defer those to the List tool.
  if (_detectList(input, provenance).isNotEmpty) {
    return const <DetectionMatch<Object?>>[];
  }
  // A URL or query string reads `%` / `/` as operators; the URL tool owns it.
  if (_detectUrl(input, provenance).isNotEmpty) {
    return const <DetectionMatch<Object?>>[];
  }
  bool matches = _mathBinaryOp.hasMatch(t);
  for (final RegExpMatch m in _mathIdent.allMatches(t.toLowerCase())) {
    final String w = m.group(0)!;
    if (_mathFunctions.contains(w) || _mathConsts.contains(w)) matches = true;
  }
  if (!matches) return const <DetectionMatch<Object?>>[];
  final MathParseResult result = MathParser.parse(t, ctx: const MathContext());
  if (result is! MathOk) return const <DetectionMatch<Object?>>[];
  return <DetectionMatch<Object?>>[
    _evidence(
      provenance: provenance,
      kind: ArtifactKind.math,
      rawValue: input,
      parserResult: result,
      confidence: .88,
      reason: 'Contains supported math operators, functions, or constants.',
      primaryToolId: 'math',
    ),
  ];
}

List<DetectionMatch<Object?>> _detectBytes(
  String input,
  ArtifactProvenance provenance,
) {
  final String t = input.trim();
  if (t.isEmpty) return const <DetectionMatch<Object?>>[];
  // Cheap reject before allocating tokens/Uint8List: must start with a digit
  // or `[`, anything else can't be an integer list.
  final int first = t.codeUnitAt(0);
  final bool startsOk =
      first == 0x5B /* [ */ || (first >= 0x30 && first <= 0x39) /* 0-9 */;
  if (!startsOk) return const <DetectionMatch<Object?>>[];
  final BytesParseResult r = BytesParser.parse(t);
  if (r is! BytesParseOk) return const <DetectionMatch<Object?>>[];
  // Single tokens stay with Number Base / Timestamp.
  if (r.bytes.length < 2) return const <DetectionMatch<Object?>>[];
  return <DetectionMatch<Object?>>[
    _evidence(
      provenance: provenance,
      kind: ArtifactKind.bytes,
      rawValue: input,
      parserResult: r,
      confidence: .9,
      reason: 'Parsed ${r.bytes.length} integers in the byte range 0–255.',
      primaryToolId: 'bytes',
    ),
  ];
}

List<DetectionMatch<Object?>> _detectX509(
  String input,
  ArtifactProvenance provenance,
) {
  final String trimmed = input.trim();
  if (!trimmed.startsWith('-----BEGIN CERTIFICATE-----') &&
      !trimmed.toLowerCase().startsWith('base64:') &&
      !trimmed.toLowerCase().startsWith('hex:')) {
    return const <DetectionMatch<Object?>>[];
  }
  try {
    final X509Inspection inspection = X509Inspector.parse(trimmed);
    return <DetectionMatch<Object?>>[
      _evidence(
        provenance: provenance,
        kind: ArtifactKind.unknown,
        rawValue: input,
        parserResult: inspection,
        confidence: .99,
        reason:
            'Parsed ${inspection.certificates.length} X.509 certificate block(s).',
        primaryToolId: 'x509_inspector',
      ),
    ];
  } catch (_) {
    return const <DetectionMatch<Object?>>[];
  }
}

List<DetectionMatch<Object?>> _detectEnvironmentConfig(
  String input,
  ArtifactProvenance provenance,
) {
  final String trimmed = input.trim();
  if (trimmed.isEmpty || (!trimmed.contains('=') && !trimmed.contains(':'))) {
    return const <DetectionMatch<Object?>>[];
  }
  try {
    final ConfigInspection inspection = EnvironmentConfigInspector.parse(input);
    if (inspection.entries.length < 2) {
      return const <DetectionMatch<Object?>>[];
    }
    return <DetectionMatch<Object?>>[
      _evidence(
        provenance: provenance,
        kind: ArtifactKind.unknown,
        rawValue: input,
        parserResult: inspection,
        confidence: .9,
        reason:
            'Parsed ${inspection.entries.length} ${inspection.format.name} configuration entries.',
        primaryToolId: 'environment_config_inspector',
      ),
    ];
  } catch (_) {
    return const <DetectionMatch<Object?>>[];
  }
}

List<DetectionMatch<Object?>> _detectHashAndPem(
  String input,
  ArtifactProvenance provenance,
) {
  final List<int>? pem = _decodePublicKeyPem(input.trim());
  if (pem != null) {
    return <DetectionMatch<Object?>>[
      _evidence(
        provenance: provenance,
        kind: ArtifactKind.hash,
        rawValue: input,
        parserResult: pem,
        confidence: .94,
        reason: 'Parsed a public-key PEM block for fingerprinting.',
        primaryToolId: 'hash',
      ),
    ];
  }
  return _detectHash(input, provenance);
}

List<int>? _decodePublicKeyPem(String input) {
  final RegExpMatch? header = RegExp(
    r'^-----BEGIN (PUBLIC KEY|RSA PUBLIC KEY)-----\r?\n',
  ).firstMatch(input);
  if (header == null) return null;
  final String type = header.group(1)!;
  final String footer = '-----END $type-----';
  if (!input.endsWith(footer)) return null;
  final String body = input
      .substring(header.end, input.length - footer.length)
      .trim();
  if (body.isEmpty || !RegExp(r'^[A-Za-z0-9+/=\r\n]+$').hasMatch(body)) {
    return null;
  }
  try {
    final List<int> decoded = base64Decode(body.replaceAll(RegExp(r'\s'), ''));
    return decoded.isEmpty ? null : decoded;
  } catch (_) {
    return null;
  }
}

// Fires only on multi-line bulleted/numbered lists: at least two non-blank
// lines, a strict majority starting with a list marker. Keeps the chip quiet
// for prose, CSV, JSON, and single lines.
final RegExp _listMarker = RegExp(r'^\s*([-*+•]|\d+[.)])\s+');

List<DetectionMatch<Object?>> _detectList(
  String input,
  ArtifactProvenance provenance,
) {
  final List<String> lines = input
      .split('\n')
      .where((String l) => l.trim().isNotEmpty)
      .toList();
  if (lines.length < 2) return const <DetectionMatch<Object?>>[];
  final int marked = lines.where(_listMarker.hasMatch).length;
  if (marked * 2 <= lines.length) return const <DetectionMatch<Object?>>[];
  return <DetectionMatch<Object?>>[
    _evidence(
      provenance: provenance,
      kind: ArtifactKind.list,
      rawValue: input,
      parserResult: List<String>.unmodifiable(lines),
      confidence: .86,
      reason: '$marked of ${lines.length} non-blank lines use list markers.',
      primaryToolId: 'list',
    ),
  ];
}
