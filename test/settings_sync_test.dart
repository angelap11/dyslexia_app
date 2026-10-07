import 'dart:async';

import 'package:dyslexia_app/core/app_settings.dart';
import 'package:dyslexia_app/features/settings/preferences_remote_store.dart';
import 'package:dyslexia_app/features/settings/provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/settings_sync_fakes.dart';

const _a = 'user-a';
const _b = 'user-b';

void main() {
  late MemorySettingsLocalStore local;
  late FakePreferencesRemoteStore remote;
  String? signedIn;
  final providers = <SettingsProvider>[];

  SettingsProvider build({PreferencesRemoteStore? remoteStore}) {
    final provider = SettingsProvider(
      localStore: local,
      remoteStore: remoteStore ?? remote,
      currentUid: () => signedIn,
      writeDebounce: const Duration(milliseconds: 40),
      connectTimeout: const Duration(milliseconds: 80),
    );
    providers.add(provider);
    return provider;
  }

  Future<void> settle([int ms = 150]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  Future<void> signIn(SettingsProvider provider, String? uid) async {
    signedIn = uid;
    await provider.switchUser(uid);
    await settle();
  }

  setUp(() {
    local = MemorySettingsLocalStore();
    remote = FakePreferencesRemoteStore();
    signedIn = null;
  });

  tearDown(() {
    for (final provider in providers) {
      provider.dispose();
    }
    providers.clear();
  });

  group('initial synchronization', () {
    test(
      'creates the remote document from this account\'s values only',
      () async {
        local.values[_a] = {'fontScale': 1.2, 'darkMode': true};
        local.values[null] = {'speechRate': 0.8};
        final settings = build();

        await signIn(settings, _a);

        expect(remote.writes, hasLength(1));
        expect(remote.writes.single.create, isTrue);
        expect(remote.writes.single.fields, {'fontScale': 1.2});
        expect(settings.syncStatus, PreferencesSyncStatus.synced);
        expect(settings.hasPendingSync, isFalse);
      },
    );

    test('never uploads defaults when the account stored nothing', () async {
      final settings = build();

      await signIn(settings, _a);

      expect(remote.writes, isEmpty);
      expect(remote.documents.containsKey(_a), isFalse);
      expect(settings.settings.toMap(), AppSettings.defaults.toMap());
      expect(settings.syncStatus, PreferencesSyncStatus.synced);
    });

    test('existing remote preferences replace stored values', () async {
      local.values[_a] = {'fontScale': 1.0, 'speechRate': 0.8};
      remote.documents[_a] = {'fontScale': 1.4, 'speechRate': 0.3};
      final settings = build();

      await signIn(settings, _a);

      expect(settings.fontScale, 1.4);
      expect(settings.speechRate, 0.3);
      expect(local.values[_a]!['fontScale'], 1.4);
      expect(remote.writes, isEmpty);
      expect(settings.syncStatus, PreferencesSyncStatus.synced);
    });

    test('pending local edits win only for their own fields', () async {
      local.values[_a] = {'speechRate': 0.8, 'fontScale': 1.0};
      local.pending[_a] = {'speechRate'};
      remote.documents[_a] = {'speechRate': 0.3, 'fontScale': 1.4};
      final settings = build();

      await signIn(settings, _a);

      expect(settings.speechRate, 0.8);
      expect(settings.fontScale, 1.4);
      expect(remote.writes.single.fields, {'speechRate': 0.8});
      expect(remote.documents[_a]!['speechRate'], 0.8);
      expect(local.pending[_a], isEmpty);
    });

    test('invalid remote values are ignored', () async {
      remote.documents[_a] = {'fontScale': 9.0, 'focusMode': 'yes'};
      final settings = build();

      await signIn(settings, _a);

      expect(settings.fontScale, AppSettings.defaultFontScale);
      expect(settings.focusMode, AppSettings.defaults.focusMode);
    });

    test(
      'unscoped signed-out settings are not applied to an account',
      () async {
        local.values[null] = {'fontScale': 1.5, 'dyslexiaFont': false};
        final settings = build();

        await signIn(settings, null);
        expect(settings.fontScale, 1.5);

        await signIn(settings, _a);
        expect(settings.fontScale, AppSettings.defaultFontScale);
        expect(settings.dyslexiaFont, AppSettings.defaults.dyslexiaFont);
        expect(remote.writes, isEmpty);
      },
    );
  });

  group('edits', () {
    test('only changed fields are written', () async {
      remote.documents[_a] = {'fontScale': 1.0};
      final settings = build();
      await signIn(settings, _a);

      await settings.setFocusMode(true);
      await settle();

      expect(remote.writes.single.fields, {'focusMode': true});
    });

    test('device-only settings are stored but never synced', () async {
      remote.documents[_a] = {'fontScale': 1.0};
      final settings = build();
      await signIn(settings, _a);

      await settings.setDarkMode(true);
      await settings.setReadingRulerEnabled(true);
      await settle();

      expect(remote.writes, isEmpty);
      expect(local.values[_a], {'darkMode': true, 'readingRulerEnabled': true});
      expect(settings.hasPendingSync, isFalse);
    });

    test(
      'slider drags are debounced into one write of the final value',
      () async {
        remote.documents[_a] = {'fontScale': 1.0};
        final settings = build();
        await signIn(settings, _a);

        for (var i = 0; i <= 10; i++) {
          unawaited(settings.setReadingRulerDimOpacity(0.2 + i * 0.05));
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        await settle();

        expect(remote.writes, hasLength(1));
        expect(
          remote.writes.single.fields['readingRulerDimOpacity'] as double,
          closeTo(0.7, 1e-9),
        );
      },
    );

    test('status stays pending until the server acknowledges', () async {
      remote.documents[_a] = {'fontScale': 1.0};
      remote.autoAcknowledge = false;
      final settings = build();
      await signIn(settings, _a);

      await settings.setSpeechRate(0.3);
      await settle();

      expect(remote.writes, hasLength(1));
      expect(settings.syncStatus, PreferencesSyncStatus.pending);
      expect(local.pending[_a], {'speechRate'});

      remote.acknowledgeAll();
      await settle(20);

      expect(settings.syncStatus, PreferencesSyncStatus.synced);
      expect(local.pending[_a], isEmpty);
    });

    test('an edit during an in-flight write keeps the field pending', () async {
      remote.documents[_a] = {'fontScale': 1.0};
      remote.autoAcknowledge = false;
      final settings = build();
      await signIn(settings, _a);

      await settings.setFontScale(1.1);
      await settle();
      await settings.setFontScale(1.3);
      remote.acknowledgeAll();
      await settle(20);

      expect(settings.pendingSyncKeys, {'fontScale'});

      remote.autoAcknowledge = true;
      await settle();
      remote.acknowledgeAll();
      await settle(20);

      expect(remote.writes.last.fields, {'fontScale': 1.3});
      expect(remote.documents[_a]!['fontScale'], 1.3);
      expect(settings.syncStatus, PreferencesSyncStatus.synced);
    });

    test(
      'remote changes on other fields merge without causing writes',
      () async {
        remote.documents[_a] = {'fontScale': 1.0, 'speechRate': 0.5};
        remote.autoAcknowledge = false;
        final settings = build();
        await signIn(settings, _a);

        await settings.setFontScale(1.3);
        await settle();
        remote.serverUpdate(_a, {'speechRate': 0.8, 'fontScale': 0.9});
        await settle(20);

        // Other device's field applies; our pending field is not overwritten.
        expect(settings.speechRate, 0.8);
        expect(settings.fontScale, 1.3);
        expect(remote.writes, hasLength(1));
        expect(remote.writes.single.fields, {'fontScale': 1.3});

        remote.acknowledgeAll();
        await settle();
        expect(remote.documents[_a], {'fontScale': 1.3, 'speechRate': 0.8});
        expect(remote.writes, hasLength(1));
      },
    );

    test('remote updates alone never trigger writes', () async {
      remote.documents[_a] = {'fontScale': 1.0};
      final settings = build();
      await signIn(settings, _a);

      remote.serverUpdate(_a, {'highContrastMode': true});
      await settle();

      expect(settings.highContrastMode, isTrue);
      expect(local.values[_a]!['highContrastMode'], isTrue);
      expect(settings.hasPendingSync, isFalse);
      expect(remote.writes, isEmpty);
    });
  });

  group('offline', () {
    test('edits wait on the device and are sent after reconnecting', () async {
      remote.documents[_a] = {'fontScale': 1.0};
      remote.goOffline();
      final settings = build();
      await signIn(settings, _a);

      expect(settings.syncWaitingForNetwork, isTrue);
      await settings.setFontScale(1.2);
      await settle();

      expect(remote.writes, isEmpty);
      expect(settings.syncStatus, PreferencesSyncStatus.pending);
      expect(local.values[_a]!['fontScale'], 1.2);
      expect(local.pending[_a], {'fontScale'});

      remote.goOnline();
      await settle();

      expect(remote.writes.single.fields, {'fontScale': 1.2});
      expect(settings.syncStatus, PreferencesSyncStatus.synced);
      expect(settings.syncWaitingForNetwork, isFalse);
      expect(local.pending[_a], isEmpty);
    });

    test('pending edits survive an app restart', () async {
      remote.documents[_a] = {'fontScale': 1.0};
      remote.goOffline();
      final first = build();
      await signIn(first, _a);
      await first.setSpeechRate(0.8);
      await settle();
      first.dispose();
      providers.remove(first);

      remote.goOnline();
      final second = build();
      await signIn(second, _a);

      expect(second.speechRate, 0.8);
      expect(remote.documents[_a]!['speechRate'], 0.8);
      expect(second.syncStatus, PreferencesSyncStatus.synced);
    });
  });

  group('account switching', () {
    test('rapid A→B→A ends with A\'s settings and one listener', () async {
      local.values[_a] = {'fontScale': 1.2};
      local.values[_b] = {'fontScale': 0.9};
      remote.documents[_a] = {'fontScale': 1.2};
      remote.documents[_b] = {'fontScale': 0.9};
      final settings = build();
      final gate = local.readGate = Completer<void>();

      signedIn = _a;
      final first = settings.switchUser(_a);
      signedIn = _b;
      final second = settings.switchUser(_b);
      signedIn = _a;
      final third = settings.switchUser(_a);
      expect(settings.fontScale, AppSettings.defaultFontScale);
      expect(settings.isReadyFor(_a), isFalse);

      gate.complete();
      await Future.wait([first, second, third]);
      await settle();

      expect(settings.isReadyFor(_a), isTrue);
      expect(settings.fontScale, 1.2);
      expect(remote.openWatchers, 1);
      expect(remote.writes, isEmpty);
    });

    test(
      'the previous account\'s settings are hidden during a switch',
      () async {
        local.values[_a] = {'fontScale': 1.4, 'darkMode': true};
        final settings = build();
        await signIn(settings, _a);
        expect(settings.darkMode, isTrue);

        final gate = local.readGate = Completer<void>();
        signedIn = _b;
        final switching = settings.switchUser(_b);

        expect(settings.isReadyFor(_b), isFalse);
        expect(settings.isSwitchingTo(_b), isTrue);
        expect(settings.darkMode, isFalse);
        expect(settings.fontScale, AppSettings.defaultFontScale);

        // Nothing editable is shown now; an edit must not land anywhere.
        await settings.setFontScale(1.5);
        expect(local.values[_b], isNull);
        expect(local.values[_a]!['fontScale'], 1.4);

        gate.complete();
        await switching;
        expect(settings.isReadyFor(_b), isTrue);
      },
    );

    test(
      'A\'s offline edits never reach B and are sent when A returns',
      () async {
        remote.documents[_a] = {'fontScale': 1.0};
        remote.documents[_b] = {'fontScale': 1.0};
        remote.goOffline();
        final settings = build();
        await signIn(settings, _a);
        await settings.setFontScale(1.4);
        await settle();
        expect(await settings.flushPendingSync(), isFalse);

        await signIn(settings, _b);
        remote.goOnline();
        await settle();

        expect(settings.fontScale, 1.0);
        expect(remote.documents[_b], {'fontScale': 1.0});
        expect(remote.writes, isEmpty);
        expect(local.pending[_b], anyOf(isNull, isEmpty));
        expect(local.pending[_a], {'fontScale'});

        await signIn(settings, _a);

        expect(settings.fontScale, 1.4);
        expect(remote.writes.single.uid, _a);
        expect(remote.documents[_a]!['fontScale'], 1.4);
        expect(remote.documents[_b], {'fontScale': 1.0});
      },
    );

    test('a late acknowledgement for A does not change B\'s state', () async {
      remote.documents[_a] = {'fontScale': 1.0};
      remote.documents[_b] = {'fontScale': 1.0};
      remote.autoAcknowledge = false;
      final settings = build();
      await signIn(settings, _a);
      await settings.setFocusMode(true);
      await settle();
      expect(remote.heldWrites, 1);

      await signIn(settings, _b);
      remote.acknowledgeAll();
      await settle();

      expect(settings.activeUid, _b);
      expect(settings.focusMode, AppSettings.defaults.focusMode);
      expect(settings.hasPendingSync, isFalse);
      expect(local.pending[_b], anyOf(isNull, isEmpty));
      // A keeps its mark; resending the same value on A's return is harmless.
      expect(local.pending[_a], {'focusMode'});
    });

    test(
      'writes are skipped when the signed-in uid no longer matches',
      () async {
        remote.documents[_a] = {'fontScale': 1.0};
        final settings = build();
        await signIn(settings, _a);

        await settings.setFontScale(1.2);
        signedIn = _b; // auth changed; the gate has not switched settings yet
        await settle();

        expect(remote.writes, isEmpty);
        expect(local.pending[_a], {'fontScale'});
      },
    );
  });

  group('availability', () {
    test(
      'missing Firestore keeps settings local with an honest state',
      () async {
        final settings = SettingsProvider(
          localStore: local,
          currentUid: () => signedIn,
        );
        providers.add(settings);
        await signIn(settings, _a);

        await settings.setFontScale(1.2);

        expect(settings.syncStatus, PreferencesSyncStatus.unavailable);
        expect(settings.fontScale, 1.2);
        expect(local.values[_a]!['fontScale'], 1.2);
      },
    );

    test('permission denied reports unavailable and keeps edits', () async {
      remote.error = const PreferencesSyncException(
        PreferencesSyncErrorKind.unavailable,
        'permission-denied',
      );
      final settings = build();
      await signIn(settings, _a);

      await settings.setSpeechRate(0.3);
      await settle();

      expect(settings.syncStatus, PreferencesSyncStatus.unavailable);
      expect(settings.speechRate, 0.3);
      expect(local.pending[_a], {'speechRate'});
    });

    test('a failed write is reported and can be retried', () async {
      remote.documents[_a] = {'fontScale': 1.0};
      final settings = build();
      await signIn(settings, _a);

      remote.error = const PreferencesSyncException(
        PreferencesSyncErrorKind.failed,
        'internal',
      );
      await settings.setFontScale(1.2);
      await settle();
      expect(settings.syncStatus, PreferencesSyncStatus.failed);
      expect(settings.hasPendingSync, isTrue);

      remote.error = null;
      await settings.retrySync();
      await settle();

      expect(settings.syncStatus, PreferencesSyncStatus.synced);
      expect(remote.documents[_a]!['fontScale'], 1.2);
    });

    test('signed out is local only', () async {
      final settings = build();
      await signIn(settings, null);

      await settings.setFontScale(1.2);
      await settle();

      expect(settings.syncStatus, PreferencesSyncStatus.localOnly);
      expect(remote.writes, isEmpty);
      expect(local.values[null]!['fontScale'], 1.2);
    });
  });
}
