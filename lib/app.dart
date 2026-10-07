import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/auth/login_screen.dart';
import 'features/history/saved_texts_controller.dart';
import 'features/home/home_screen.dart';
import 'features/settings/provider.dart';
import 'core/theme.dart';

class MyApp extends StatelessWidget {
  final SettingsProvider settingsProvider;

  /// Saved texts (History) of the signed-in account.
  final SavedTextsController? savedTextsController;

  @visibleForTesting
  final Stream<User?> Function()? authStateChanges;

  @visibleForTesting
  final WidgetBuilder? sessionHomeBuilder;

  const MyApp({
    super.key,
    required this.settingsProvider,
    this.savedTextsController,
    this.authStateChanges,
    this.sessionHomeBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final savedTexts = savedTextsController;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        if (savedTexts != null) ChangeNotifierProvider.value(value: savedTexts),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          // One stable MaterialApp for the whole process. Never swap to a
          // second MaterialApp when settings reload — that re-inserts the
          // WidgetsApp Navigator GlobalKey and triggers:
          // "A GlobalKey was used multiple times inside one widget's child list."
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'ЧитајЛесно',
            theme: buildAppTheme(
              dyslexiaFont: settings.dyslexiaFont,
              isDark: false,
              focusMode: settings.focusMode,
              highContrast: settings.highContrastMode,
            ),
            darkTheme: buildAppTheme(
              dyslexiaFont: settings.dyslexiaFont,
              isDark: true,
              focusMode: settings.focusMode,
              highContrast: settings.highContrastMode,
            ),
            themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(settings.textScaleFactor),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: _AuthGate(
              settingsProvider: settingsProvider,
              savedTexts: savedTexts,
              authStateChanges: authStateChanges,
              sessionHomeBuilder: sessionHomeBuilder,
            ),
          );
        },
      ),
    );
  }
}

class _BootLoadingScreen extends StatelessWidget {
  const _BootLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}

/// Listens to Firebase auth state changes and, on every transition,
/// switches settings and saved texts to the newly signed-in user. An
/// account's screens are built only after its own settings are loaded, so
/// no data bleeds across accounts.
class _AuthGate extends StatefulWidget {
  final SettingsProvider settingsProvider;
  final SavedTextsController? savedTexts;
  final Stream<User?> Function()? authStateChanges;
  final WidgetBuilder? sessionHomeBuilder;

  const _AuthGate({
    required this.settingsProvider,
    this.savedTexts,
    this.authStateChanges,
    this.sessionHomeBuilder,
  });

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  String? _lastUid;
  bool _switchScheduled = false;
  String? _scheduledUid;

  // Subscribed once. authStateChanges() returns a new Stream per call, and a
  // new stream resets StreamBuilder to `waiting`, which would unmount the
  // session Navigator (and every open screen) on each settings change.
  late final Stream<User?> _authStateChanges;

  @override
  void initState() {
    super.initState();
    _authStateChanges =
        widget.authStateChanges?.call() ??
        FirebaseAuth.instance.authStateChanges();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _BootLoadingScreen();
        }

        final user = snapshot.data;
        final newUid = user?.uid;

        _lastUid = newUid;
        _ensureSavedTextsFor(newUid);

        if (!widget.settingsProvider.isReadyFor(newUid)) {
          _ensureSettingsFor(newUid);
          return const _BootLoadingScreen();
        }

        // AuthGate owns Login ↔ session. Authenticated screens (Profile, OCR,
        // TTS, …) are pushed on a nested Navigator keyed by uid. On signOut
        // that Navigator is disposed, so the stack cannot keep Profile/Home
        // above Login (and Android Back cannot return to them).
        if (user != null) {
          return Navigator(
            key: ValueKey<String>('auth-session-${user.uid}'),
            onGenerateRoute: (settings) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: widget.sessionHomeBuilder ?? (_) => const HomeScreen(),
              );
            },
          );
        }

        return const LoginScreen(key: ValueKey<String>('auth-login'));
      },
    );
  }

  /// Switching notifies listeners, so it cannot run during this build.
  void _ensureSettingsFor(String? uid) {
    final settings = widget.settingsProvider;
    if (settings.isSwitchingTo(uid)) return;
    if (_switchScheduled && _scheduledUid == uid) return;
    _switchScheduled = true;
    _scheduledUid = uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _switchScheduled = false;
      if (!mounted || _lastUid != uid) return;
      if (settings.isReadyFor(uid) || settings.isSwitchingTo(uid)) return;
      settings.switchUser(uid);
    });
  }

  /// The controller clears the previous account's History as soon as the
  /// switch starts; it notifies listeners, so it runs after this build.
  void _ensureSavedTextsFor(String? uid) {
    final savedTexts = widget.savedTexts;
    if (savedTexts == null || savedTexts.uid == uid) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastUid != uid || savedTexts.uid == uid) return;
      savedTexts.switchUser(uid);
    });
  }
}
