/// Akar app: MaterialApp, tema, locale ikut settings, shell 5 tab.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/game_controller.dart';
import 'theme.dart';
import '../ui/shell.dart';

class MeridianApp extends ConsumerWidget {
  const MeridianApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider).value;
    final settings = state?.settings;
    return MaterialApp(
      title: 'Meridian Tycoon',
      debugShowCheckedModeBanner: false,
      theme: MeridianTheme.light(),
      darkTheme: MeridianTheme.dark(),
      themeMode: (settings?.darkMode ?? true) ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(settings?.lang ?? 'ms'),
      supportedLocales: const [Locale('en'), Locale('ms'), Locale('id')],
      home: const GameShell(),
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    );
  }
}
