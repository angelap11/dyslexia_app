import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_options.dart';
import 'app.dart';
import 'features/history/saved_texts_controller.dart';
import 'features/history/saved_texts_remote.dart';
import 'features/settings/preferences_remote_store.dart';
import 'features/settings/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Hive.initFlutter();

  final uid = FirebaseAuth.instance.currentUser?.uid;
  final settingsProvider = SettingsProvider(
    remoteStore: FirestorePreferencesRemoteStore.tryCreate(),
  );
  await settingsProvider.switchUser(uid);

  final savedTextsController = SavedTextsController(
    remote: FirestoreSavedTextsRemote.tryCreate(),
  );
  // History loads in the background; it is not needed for the first frame.
  unawaited(savedTextsController.switchUser(uid));

  runApp(
    MyApp(
      settingsProvider: settingsProvider,
      savedTextsController: savedTextsController,
    ),
  );
}
