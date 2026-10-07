import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/state/canvas_controller.dart';
import 'package:masquerade/state/link_group.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/desktop/desktop_menubar.dart';
import 'package:masquerade/widgets/mq/tool_action_bar.dart';
import 'package:masquerade/widgets/tool_bodies/seed_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('moving cards reuses bodies and link changes replace them', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MyApp(
        desktopShellOverride: true,
        viewModeController: ViewModeController(initial: MqViewMode.desktop),
        skipSplash: true,
      ),
    );
    await tester.pumpAndSettle();

    final CanvasController canvas = tester
        .widget<DesktopMenubar>(find.byType(DesktopMenubar))
        .controller;
    int bodyBuilds = 0;
    final UtilityDescriptor descriptor = _counted(
      UtilityCatalog.byId('uuid'),
      () => bodyBuilds++,
    );
    final int first = canvas.openTool(descriptor);
    final int second = canvas.openTool(descriptor);
    await tester.pump();
    expect(bodyBuilds, 2);

    canvas.moveBy(first, 20, 10);
    await tester.pump();
    expect(bodyBuilds, 2);

    canvas.linkCards(first, second, type: ContentType.text);
    await tester.pump();
    expect(bodyBuilds, 4);

    canvas.unlinkCard(first);
    await tester.pump();
    expect(bodyBuilds, 6);
  });
}

UtilityDescriptor _counted(UtilityDescriptor source, VoidCallback onBuild) =>
    UtilityDescriptor(
      id: source.id,
      name: source.name,
      description: source.description,
      icon: source.icon,
      tint: source.tint,
      synonyms: source.synonyms,
      categories: source.categories,
      acceptedTypes: source.acceptedTypes,
      producedTypes: source.producedTypes,
      sensitivity: source.sensitivity,
      inputSources: source.inputSources,
      liveLinkTypes: source.liveLinkTypes,
      quickActions: source.quickActions,
      batchCapable: source.batchCapable,
      historyPolicy: source.historyPolicy,
      defaultCardWidth: source.defaultCardWidth,
      detectArtifact: source.detectArtifact,
      builder:
          (
            BuildContext context, {
            String? initialInput,
            Artifact<Object?>? initialArtifact,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
            LinkChannel? link,
          }) {
            onBuild();
            return source.builder(
              context,
              initialInput: initialInput,
              initialArtifact: initialArtifact,
              seedSource: seedSource,
              onSwitchTool: onSwitchTool,
              actionBar: actionBar,
              link: link,
            );
          },
    );
