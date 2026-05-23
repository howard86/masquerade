import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/window_content.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/mq/mq_icons.dart';

void main() {
  group('ToolWindow', () {
    test('persistId is tool:<id>', () {
      final UtilityDescriptor d = UtilityCatalog.byId('json');
      final ToolWindow tw = ToolWindow(d);
      expect(tw.persistId, 'tool:json');
    });

    test('title/icon/tint delegate to descriptor', () {
      final UtilityDescriptor d = UtilityCatalog.byId('timestamp');
      final ToolWindow tw = ToolWindow(d);
      expect(tw.title, d.name);
      expect(tw.icon, d.icon);
      expect(tw.tint, d.tint);
    });
  });

  group('SystemWindow', () {
    test('persistId is system:<name>', () {
      expect(const SystemWindow(SystemApp.history).persistId, 'system:history');
      expect(
        const SystemWindow(SystemApp.settings).persistId,
        'system:settings',
      );
    });

    test('title returns human-readable name', () {
      expect(const SystemWindow(SystemApp.history).title, 'History');
      expect(const SystemWindow(SystemApp.settings).title, 'Settings');
    });

    test('icon returns the correct glyph', () {
      expect(const SystemWindow(SystemApp.history).icon, MqIcons.history);
      expect(const SystemWindow(SystemApp.settings).icon, MqIcons.setting);
    });
  });
}
