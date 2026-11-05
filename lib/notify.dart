// Telefon bildirimleri: son güne 30, 7, 1 gün kala ve son gün sabahı
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'entitlement.dart';
import 'models.dart';

class Notifier {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Bildirimlerin geleceği saat (varsayılan 10:00)
  static int hour = 10;
  static int minute = 0;

  static Future<void> loadTime() async {
    final p = await SharedPreferences.getInstance();
    final t = p.getString('notify_time');
    if (t != null && t.contains(':')) {
      hour = int.tryParse(t.split(':')[0]) ?? 10;
      minute = int.tryParse(t.split(':')[1]) ?? 0;
    }
  }

  static Future<void> setTime(int h, int m, List<Item> items) async {
    hour = h;
    minute = m;
    final p = await SharedPreferences.getInstance();
    await p.setString('notify_time', '$h:$m');
    await rescheduleAll(items);
  }

  static String get timeText => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

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
        android: AndroidInitializationSettings('@drawable/ic_stat_notify'),
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
      final offsets = it.kind.offsets;
      for (final off in offsets) {
        final d = due.subtract(Duration(days: off));
        final when = tz.TZDateTime(tz.local, d.year, d.month, d.day, hour, minute);
        if (!when.isAfter(now)) continue;
        final body = off == 0
            ? 'Dürt dürt! Bugün son gün: ${fmtDate(due)}'
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
