import 'dart:io';

import 'package:dyslexia_app/features/settings/settings_local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('HiveSettingsLocalStore', () {
    late Directory dir;
    final store = HiveSettingsLocalStore();

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('settings_store_test');
      Hive.init(dir.path);
      SharedPreferences.setMockInitialValues({
        'fontSize': 26.0,
        'dyslexiaFont': false,
        'speechRate': 0.8,
      });
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('legacy settings seed only the signed-out scope', () async {
      final signedOut = await store.read(null);
      expect(signedOut['dyslexiaFont'], isFalse);
      expect(signedOut['speechRate'], 0.8);

      expect(await store.read('user-a'), isEmpty);

      // Legacy keys are kept, never deleted.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('fontSize'), 26.0);
    });

    test('accounts and pending sets are scoped per uid', () async {
      await store.write('user-a', {'fontScale': 1.2});
      await store.writePending('user-a', {'fontScale'});

      expect(await store.read('user-a'), {'fontScale': 1.2});
      expect(await store.read('user-b'), isEmpty);
      expect(await store.readPending('user-a'), {'fontScale'});
      expect(await store.readPending('user-b'), isEmpty);
    });

    test('write keeps other stored keys', () async {
      await store.write('user-a', {'fontScale': 1.2, 'darkMode': true});
      await store.write('user-a', {'fontScale': 1.4});

      expect(await store.read('user-a'), {'fontScale': 1.4, 'darkMode': true});
    });

    test('retired Word Focus keys are removed, legacy boxes kept', () async {
      await store.write('user-a', {'wordFocusEnabled': true, 'fontScale': 1.2});

      expect(await store.read('user-a'), {'fontScale': 1.2});
      expect(await store.read(null), isNotEmpty);
    });
  });
}
