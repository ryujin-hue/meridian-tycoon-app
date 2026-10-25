import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/i18n.dart';
import 'state/game_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await preloadAppStrings();
  runApp(const ProviderScope(child: MeridianApp()));
  // Pemuatan game berlaku dalam GameShell (controller build) — tidak menyekat
  // render pertama; data remote dikemas kini di latar belakang selepas itu.
}

/// Helper global untuk memicu semakan kemas kini data dari UI.
void triggerDataUpdateCheck(WidgetRef ref) {
  ref.read(gameControllerProvider.notifier).backgroundDataUpdateCheck();
}
