import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/database/note_repository.dart';
import 'features/splash/noted_splash_screen.dart';
import 'providers/notes_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home/home_screen.dart';
import 'widgets/app_icon_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Hive.initFlutter();
    final repository = NoteRepository();
    await repository.init();
    final settings = await Hive.openBox('settings');

    runApp(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotesProvider(repository)),
        ChangeNotifierProvider(create: (_) => ThemeProvider(settings)),
      ],
      child: const NotedApp(),
    ));
  } catch (_) {
    // Never show a stack trace, and never touch the stored data on failure.
    runApp(const _StartupError());
  }
}

class NotedApp extends StatelessWidget {
  const NotedApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ThemeProvider>().mode;
    return MaterialApp(
      title: 'Noted.',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      builder: (context, child) => AppIconSync(child: child ?? const SizedBox.shrink()),
      home: const NotedSplashScreen(next: HomeScreen()),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              "Couldn't open your notes. Your data hasn't been changed. Please restart the app.",
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
