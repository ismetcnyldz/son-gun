// Telefon bildirimleri: son güne 30, 7, 1 gün kala ve son gün sabahı
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'entitlement.dart';
import 'models.dart';

class Notifier {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'hatirlatmalar',
      'Hatırlatmalar',
      channelDescription: 'Son tarih hatırlatmaları',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Bildirim izni iste (hoş geldin ekranında ve sonraki açılışlarda)
  static Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return (android ?? false) || (ios ?? false);
  }

  /// Tüm bildirimleri silip baştan kurar (kayıt sayısı az olduğu için en güvenli yol).
  static Future<void> rescheduleAll(List<Item> items) async {
    if (!_ready) return;
    await _plugin.cancelAll();
    if (!entitlement.active) return; // deneme / abonelik bitince hatırlatma yok
    final now = tz.TZDateTime.now(tz.local);
    var id = 1;
    for (final it in items) {
      final due = it.nextDue();
      if (due == null) continue;
      final offsets = it.kind.monthly ? const [3, 1, 0] : const [30, 7, 1, 0];
      for (final off in offsets) {
        final d = due.subtract(Duration(days: off));
        final when = tz.TZDateTime(tz.local, d.year, d.month, d.day, 10);
        if (!when.isAfter(now)) continue;
        final body = off == 0
            ? 'Bugün son gün: ${fmtDate(due)}'
            : '$off gün kaldı · Son gün ${fmtDate(due)}';
        try {
          await _plugin.zonedSchedule(
            id++,
            it.title,
            body,
            when,
            _details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (_) {/* tek bildirim hatası diğerlerini durdurmasın */}
        if (id > 400) return; // Android sınırının altında kal
      }
    }
  }
}
