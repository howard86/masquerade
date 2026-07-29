import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/state/library_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/mq/tool_grid_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size _phone = Size(393, 852);

Future<void> _pumpLibrary(
  WidgetTester tester, {
  HistoryController? history,
  LibraryController? library,
}) async {
  await tester.binding.setSurfaceSize(_phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MyApp(
      isWebOverride: false,
      skipSplash: true,
      historyController: history,
      libraryController: library,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Library').last);
  await tester.pumpAndSettle();
}

List<String> _cardIds(WidgetTester tester) => tester
    .widgetList<ToolGridCard>(find.byType(ToolGridCard))
    .map((ToolGridCard card) => card.descriptor.id)
    .toList();

Future<void> _expectStableMainCatalog(WidgetTester tester) async {
  if (_cardIds(tester).length < UtilityCatalog.all.length) {
    await tester.scrollUntilVisible(
      find.text('ALL TOOLS'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }
  final List<String> ids = _cardIds(tester);
  expect(ids.length, greaterThanOrEqualTo(UtilityCatalog.all.length));
  expect(
    ids.sublist(ids.length - UtilityCatalog.all.length),
    UtilityCatalog.all.map((UtilityDescriptor u) => u.id),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('category filters the stable catalog', (
    WidgetTester tester,
  ) async {
    await _pumpLibrary(tester);

    expect(_cardIds(tester), UtilityCatalog.all.map((u) => u.id));

    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();

    expect(
      _cardIds(tester),
      UtilityCatalog.inCategory(
        UtilityCategory.generate,
      ).map((UtilityDescriptor u) => u.id),
    );
  });

  testWidgets('cards expose catalog routing and history metadata', (
    WidgetTester tester,
  ) async {
    await _pumpLibrary(tester);

    final ToolGridCard uuid = tester.widget<ToolGridCard>(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is ToolGridCard && widget.descriptor.id == 'uuid',
      ),
    );
    expect(uuid.showMetadata, isTrue);
    expect(
      find.descendant(
        of: find.byWidgetPredicate((Widget widget) => identical(widget, uuid)),
        matching: find.text(uuid.descriptor.metadataSummary),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'favorites and recents stay separate from the stable main catalog',
    (WidgetTester tester) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final HistoryController history = HistoryController(prefs: prefs);
      final LibraryController library = LibraryController(prefs: prefs);
      final DateTime now = DateTime.now();
      await history.add(
        HistoryEntry(
          utilityId: 'json',
          input: '{}',
          output: '{}',
          timestamp: now,
        ),
      );
      await history.add(
        HistoryEntry(
          utilityId: 'base64',
          input: 'hello',
          output: 'aGVsbG8=',
          timestamp: now.add(const Duration(seconds: 1)),
        ),
      );

      await _pumpLibrary(tester, history: history, library: library);

      expect(find.text('RECENTLY USED'), findsOneWidget);
      await _expectStableMainCatalog(tester);

      final Finder base64Favorite = find
          .descendant(
            of: find.byWidgetPredicate(
              (Widget widget) =>
                  widget is ToolGridCard && widget.descriptor.id == 'base64',
            ),
            matching: find.byType(CupertinoButton),
          )
          .first;
      await tester.tap(base64Favorite);
      await tester.pumpAndSettle();
      expect(find.text('FAVORITES'), findsOneWidget);
      expect(library.isFavorite('base64'), isTrue);
      await _expectStableMainCatalog(tester);

      await history.add(
        HistoryEntry(
          utilityId: 'timestamp',
          input: '1700000000',
          output: '2023-11-14T22:13:20.000Z',
          timestamp: now.add(const Duration(seconds: 2)),
        ),
      );
      await tester.pump();
      await _expectStableMainCatalog(tester);
    },
  );

  testWidgets('search finds tools across categories in stable order', (
    WidgetTester tester,
  ) async {
    await _pumpLibrary(tester);

    await tester.enterText(find.byType(CupertinoTextField), 'encode');
    await tester.pump();

    expect(
      _cardIds(tester),
      UtilityCatalog.searchStable('encode').map((UtilityDescriptor u) => u.id),
    );
    expect(find.text('SEARCH RESULTS'), findsOneWidget);
  });

  testWidgets('clear affordance empties the field and resets the filter', (
    WidgetTester tester,
  ) async {
    await _pumpLibrary(tester);

    await tester.enterText(find.byType(CupertinoTextField), 'encode');
    await tester.pump();
    expect(find.text('SEARCH RESULTS'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Clear search'));
    await tester.pump();

    expect(
      tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.text('SEARCH RESULTS'), findsNothing);
    await _expectStableMainCatalog(tester);
  });
}
