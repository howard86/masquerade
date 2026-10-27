// Barrel of every tool body, loaded as ONE deferred library by
// `deferred_tool_body.dart` so the bodies (and their body-only utils) stay
// out of web's main.dart.js. Nothing else may import this file eagerly, or
// dart2js folds it back into the main unit.

import 'package:flutter/widgets.dart';

import 'artifact_inspector_body.dart';
import 'base64_body.dart';
import 'bps_body.dart';
import 'bytes_body.dart';
import 'case_body.dart';
import 'color_body.dart';
import 'cron_body.dart';
import 'csv_body.dart';
import 'deferred_tool_body.dart';
import 'diff_body.dart';
import 'environment_config_inspector_body.dart';
import 'generator_body.dart';
import 'hash_body.dart';
import 'http_inspector_body.dart';
import 'ip_body.dart';
import 'json_body.dart';
import 'jwt_body.dart';
import 'list_body.dart';
import 'log_stack_inspector_body.dart';
import 'math_body.dart';
import 'markdown_body.dart';
import 'number_base_body.dart';
import 'qr_code_body.dart';
import 'regex_body.dart';
import 'timestamp_body.dart';
import 'unicode_string_inspector_body.dart';
import 'url_body.dart';
import 'uuid_body.dart';
import 'x509_inspector_body.dart';

/// Builds the real body for [kind]. Called only once the library is loaded.
Widget buildToolBody(ToolBodyKind kind, ToolBodyArgs a) => switch (kind) {
  ToolBodyKind.environmentConfigInspector => EnvironmentConfigInspectorBody(
    initialInput: a.initialInput,
    initialArtifact: a.initialArtifact,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
  ),
  ToolBodyKind.logStackInspector => LogStackInspectorBody(
    initialInput: a.initialInput,
    initialArtifact: a.initialArtifact,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
  ),
  ToolBodyKind.unicodeStringInspector => UnicodeStringInspectorBody(
    initialInput: a.initialInput,
    initialArtifact: a.initialArtifact,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
  ),
  ToolBodyKind.x509Inspector => X509InspectorBody(
    initialInput: a.initialInput,
    initialArtifact: a.initialArtifact,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
  ),
  ToolBodyKind.httpInspector => HttpInspectorBody(
    initialInput: a.initialInput,
    initialArtifact: a.initialArtifact,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
  ),
  ToolBodyKind.artifactInspector => ArtifactInspectorBody(
    initialInput: a.initialInput,
    initialArtifact: a.initialArtifact,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
    link: a.link,
  ),
  ToolBodyKind.uuid => UuidBody(
    initialInput: a.initialInput,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
    link: a.link,
  ),
  ToolBodyKind.ip => IpBody(
    initialInput: a.initialInput,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
    link: a.link,
  ),
  ToolBodyKind.numberBase => NumberBaseBody(
    initialInput: a.initialInput,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
    link: a.link,
  ),
  ToolBodyKind.timestamp => TimestampBody(
    initialInput: a.initialInput,
    initialArtifact: a.initialArtifact,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
    link: a.link,
  ),
  ToolBodyKind.cron => CronBody(
    initialInput: a.initialInput,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
  ),
  ToolBodyKind.json => JSONBody(
    initialInput: a.initialInput,
    initialArtifact: a.initialArtifact,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
    link: a.link,
  ),
  ToolBodyKind.csv => CsvBody(
    initialInput: a.initialInput,
    initialArtifact: a.initialArtifact,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
  ),
  ToolBodyKind.jwt => JwtBody(
    initialInput: a.initialInput,
    initialArtifact: a.initialArtifact,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
  ),
  ToolBodyKind.base64 => Base64Body(
    initialInput: a.initialInput,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
    link: a.link,
  ),
  ToolBodyKind.textCase => CaseBody(
    initialInput: a.initialInput,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
  ),
  ToolBodyKind.url => UrlBody(
    initialInput: a.initialInput,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
    link: a.link,
  ),
  ToolBodyKind.color => ColorBody(
    initialInput: a.initialInput,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
    link: a.link,
  ),
  ToolBodyKind.math => MathBody(
    initialInput: a.initialInput,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
    link: a.link,
  ),
  ToolBodyKind.bps => BpsBody(
    initialInput: a.initialInput,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
  ),
  ToolBodyKind.bytes => BytesBody(
    initialInput: a.initialInput,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
  ),
  ToolBodyKind.list => ListToolBody(
    initialInput: a.initialInput,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
    link: a.link,
  ),
  ToolBodyKind.regex => RegexBody(
    initialInput: a.initialInput,
    seedSource: a.seedSource,
    actionBar: a.actionBar,
  ),
  ToolBodyKind.diff => DiffBody(
    initialInput: a.initialInput,
    seedSource: a.seedSource,
    actionBar: a.actionBar,
    link: a.link,
  ),
  ToolBodyKind.hash => HashBody(
    initialInput: a.initialInput,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
  ),
  ToolBodyKind.qrCode => QrCodeBody(
    initialInput: a.initialInput,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
  ),
  ToolBodyKind.generator => GeneratorBody(
    initialInput: a.initialInput,
    seedSource: a.seedSource,
    onSwitchTool: a.onSwitchTool,
    actionBar: a.actionBar,
    link: a.link,
  ),
  ToolBodyKind.markdown => MarkdownBody(
    initialInput: a.initialInput,
    initialArtifact: a.initialArtifact,
    seedSource: a.seedSource,
    actionBar: a.actionBar,
  ),
};
