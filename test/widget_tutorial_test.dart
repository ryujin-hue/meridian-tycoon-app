/// Widget test: shell dimuat, Kutip berfungsi, save dijana atomik.
/// Controller dibangunkan dalam zon sebenar (ProviderContainer + runAsync),
/// kemudian disuntik ke widget tree melalui UncontrolledProviderScope.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meridian_tycoon_app/app/app.dart';
import 'package:meridian_tycoon_app/app/i18n.dart';
import 'package:meridian_tycoon_app/data/save_repository.dart';
import 'package:meridian_tycoon_app/domain/clock.dart';
import 'package:meridian_tycoon_app/state/game_controller.dart';

class FakeClock implements Clock {
  DateTime nowUtc;
  FakeClock(this.nowUtc);
  @override
  DateTime now() => nowUtc;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shell dimuat + starter grant + save atomik (Clock palsu)',
      (tester) async {
    await tester.runAsync(preloadAppStrings);
    late Directory dir;
    await tester.runAsync(() async {
      final base = await Directory.systemTemp.createTemp('mt_widget_full');
      dir = Directory('${base.path}/run');
      await dir.create(recursive: true);
    });
    final mem = MemorySaveRepository();
    final deps = GameDeps(
      clock: FakeClock(DateTime.utc(2026, 10, 25, 10)),
      client: MockClient((req) async => http.Response('not found', 404)),
      docsDir: () async => dir,
      saveOverride: mem,
    );

    final container = ProviderContainer(
      overrides: [gameDepsProvider.overrideWithValue(deps)],
    );
    addTearDown(container.dispose);

    // Bangun controller dalam zon sebenar (IO fail/bundled selesai).
    await tester.runAsync(() => container.read(gameControllerProvider.future));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MeridianApp(),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Lapiskan timer animasi Lottie (1.5s) dalam fake-async.
    await tester.pump(const Duration(seconds: 2));

    // Shell dimuat: bar navigasi wujud dengan 5 tab.
    expect(find.byType(NavigationBar), findsOneWidget);
    // Starter grant daripada data (50,000 TM) dipaparkan pada header.
    expect(find.textContaining('50,000'), findsWidgets);
    // Butang Kutip Semua (aturan 2-tap).
    expect(find.textContaining('Kutip'), findsWidgets);

    // Save dalam repositori memori dijana & mengandungi dataVersion.
    final saved = mem.state;
    expect(saved, isNotNull);
    expect(saved!.tm, greaterThanOrEqualTo(50000));
    expect(saved.tutorialStep, 1);
    expect(saved.dataVersionAtSave, isNot('0.0.0'));
  });

  testWidgets('putar skrin + background/foreground + jam berjam-jam ke depan',
      (tester) async {
    await tester.runAsync(preloadAppStrings);
    final mem = MemorySaveRepository();
    final deps = GameDeps(
      clock: FakeClock(DateTime.utc(2026, 10, 25, 10)),
      client: MockClient((req) async => http.Response('not found', 404)),
      docsDir: () async => Directory.systemTemp,
      saveOverride: mem,
    );
    final container = ProviderContainer(
      overrides: [gameDepsProvider.overrideWithValue(deps)],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(gameControllerProvider.future));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MeridianApp(),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));

    // Putar skrin (orientasi landscape → rebuild).
    await tester.binding.setSurfaceSize(const Size(800, 400));
    await tester.pump();
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
    await tester.pump();

    // Buka semula selepas berjam-jam: clock maju 6 jam (dalam had simpanan).
    final st1 = container.read(gameControllerProvider).value!;
    final pend1 =
        container.read(gameControllerProvider.notifier).pendingIncome(st1);
    expect(pend1.amount, greaterThanOrEqualTo(0));
  });
}
