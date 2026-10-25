/// Notifikasi tempatan (Android 13+): HANYA keputusan (bidaan tamat,
/// pelabur menjawab). Maksimum 2 sehari (kaunter dalam save — controller).
/// Pemasaran MATI. Tiada kebenaran alarm tepat — penjadualan inexact sahaja.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../app/i18n.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
    );
    // Kebenaran Android 13+ diminta HANYA apabila pemain aktifkan tetapan.
    _ready = true;
  }

  /// Minta kebenaran (Android 13+) — dipanggil dari Settings apabila diaktifkan.
  Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  static const AndroidNotificationDetails _details = AndroidNotificationDetails(
    'auction_results',
    'Auction results',
    channelDescription: 'Only auction and investor results, max 2/day',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  /// Jadualkan notifikasi keputusan lelongan (inexact — tiada alarm tepat).
  Future<void> scheduleAuctionResult({
    required int id,
    required DateTime endUtc,
    required String titleKey,
    required String bodyKey,
    required I18n i18n,
  }) async {
    if (!_ready) return;
    final when = tz.TZDateTime.from(endUtc, tz.local);
    if (when.isBefore(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      id: id,
      title: i18n.t(titleKey),
      body: i18n.t(bodyKey),
      scheduledDate: when,
      notificationDetails:
          const NotificationDetails(android: _details),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'auction',
    );
  }

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: _details),
      payload: 'result',
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id: id);
}
