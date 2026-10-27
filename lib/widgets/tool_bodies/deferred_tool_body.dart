import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../models/artifact.dart';
import '../../state/link_group.dart';
import '../../theme/mq_theme.dart';
import '../../utility_catalog.dart';
import '../mq/tool_action_bar.dart';
import 'all_bodies.dart' deferred as bodies;
import 'seed_source.dart';

/// Which body [buildToolBody] constructs. One value per catalog entry; the
/// enum lives here (eager) so the catalog can name a body without touching
/// the deferred barrel.
enum ToolBodyKind {
  environmentConfigInspector,
  logStackInspector,
  unicodeStringInspector,
  x509Inspector,
  httpInspector,
  artifactInspector,
  uuid,
  ip,
  numberBase,
  timestamp,
  cron,
  json,
  csv,
  jwt,
  base64,
  textCase,
  url,
  color,
  math,
  bps,
  bytes,
  list,
  regex,
  diff,
  hash,
  qrCode,
  generator,
  markdown,
}

/// The [UtilityBuilder] arguments, carried across the deferred boundary.
@immutable
class ToolBodyArgs {
  const ToolBodyArgs({
    this.initialInput,
    this.initialArtifact,
    this.seedSource = SeedSource.none,
    this.onSwitchTool,
    this.actionBar,
    this.link,
  });

  final String? initialInput;
  final Artifact<Object?>? initialArtifact;
  final SeedSource seedSource;
  final OpenInToolCallback? onSwitchTool;
  final ToolActionBarController? actionBar;
  final LinkChannel? link;
}

Future<void>? _loading;
bool _loaded = false;

/// Whether the deferred tool-body library is loaded, so bodies build
/// synchronously.
bool get toolBodiesLoaded => _loaded;

/// Loads the deferred tool-body library once. The app calls it after the
/// first frame so the part is warm before the first tap; tests await it in
/// `test/flutter_test_config.dart`. A failed load is forgotten so the next
/// call retries. The load runs in the root zone: it is a process-wide cache,
/// so it must not bind to whichever zone (e.g. a test's fake-async zone)
/// happened to ask first.
Future<void> ensureToolBodiesLoaded() {
  if (_loaded) return Future<void>.value();
  return _loading ??= Zone.root.run<Future<void>>(_load);
}

Future<void> _load() async {
  try {
    await bodies.loadLibrary();
    _loaded = true;
  } catch (_) {
    _loading = null;
    rethrow;
  }
}

/// A catalog [UtilityBuilder] that renders [kind]'s body through
/// [DeferredToolBody].
UtilityBuilder deferredToolBuilder(ToolBodyKind kind) =>
    (
      BuildContext _, {
      String? initialInput,
      Artifact<Object?>? initialArtifact,
      SeedSource seedSource = SeedSource.none,
      OpenInToolCallback? onSwitchTool,
      ToolActionBarController? actionBar,
      LinkChannel? link,
    }) => DeferredToolBody(
      kind: kind,
      args: ToolBodyArgs(
        initialInput: initialInput,
        initialArtifact: initialArtifact,
        seedSource: seedSource,
        onSwitchTool: onSwitchTool,
        actionBar: actionBar,
        link: link,
      ),
    );

/// Renders the real tool body synchronously once the deferred library is
/// loaded; until then a plain themed surface stands in (no spinner) and is
/// swapped for the body when the load lands.
class DeferredToolBody extends StatefulWidget {
  const DeferredToolBody({super.key, required this.kind, required this.args});

  final ToolBodyKind kind;
  final ToolBodyArgs args;

  @override
  State<DeferredToolBody> createState() => _DeferredToolBodyState();
}

class _DeferredToolBodyState extends State<DeferredToolBody> {
  @override
  void initState() {
    super.initState();
    if (!_loaded) {
      ensureToolBodiesLoaded().then<void>(
        (_) {
          if (mounted) setState(() {});
        },
        onError: (Object e, StackTrace s) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: e,
              stack: s,
              library: 'deferred_tool_body',
              context: ErrorDescription('loading the tool bodies'),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded) return bodies.buildToolBody(widget.kind, widget.args);
    return Container(
      key: const ValueKey<String>('deferred-tool-body-placeholder'),
      height: 160,
      color: MqTheme.of(context).colors.surface,
    );
  }
}
