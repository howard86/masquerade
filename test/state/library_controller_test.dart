import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/library_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('favorites persist across controller reloads', () async {
    final LibraryController controller = await LibraryController.load();

    await controller.toggleFavorite('json');
    await controller.toggleFavorite('uuid');

    final LibraryController reloaded = await LibraryController.load();
    expect(reloaded.favorites, <String>{'json', 'uuid'});

    await reloaded.toggleFavorite('json');
    expect((await LibraryController.load()).favorites, <String>{'uuid'});
  });
}
