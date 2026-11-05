// Kayıtların telefonda saklanması ve hatırlatmaların kurulması
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'notify.dart';

class Store extends ChangeNotifier {
  static const _key = 'items_v1';
  final List<Item> items = [];
  bool loaded = false;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_key);
    items.clear();
    if (s != null && s.isNotEmpty) {
      try {
        items.addAll(Item.decodeList(s));
      } catch (_) {/* bozuk veri: boş başla */}
    }
    loaded = true;
    notifyListeners();
    await Notifier.rescheduleAll(items);
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, Item.encodeList(items));
    notifyListeners();
    await Notifier.rescheduleAll(items);
  }

  Future<void> upsert(Item it) async {
    final i = items.indexWhere((e) => e.id == it.id);
    if (i >= 0) {
      items[i] = it;
    } else {
      items.add(it);
    }
    await _save();
  }

  Future<void> remove(String id) async {
    items.removeWhere((e) => e.id == id);
    await _save();
  }

  Future<void> refreshReminders() => Notifier.rescheduleAll(items);

  /// Son günü olan kayıtlar, en yakından uzağa
  List<Item> upcoming() {
    final l = items.where((e) => e.nextDue() != null).toList();
    l.sort((a, b) => a.nextDue()!.compareTo(b.nextDue()!));
    return l;
  }

  /// Birden çok kayıt ekle (aynı başlık + not + tarih varsa tekrar eklemez)
  Future<int> addMany(List<Item> list) async {
    var n = 0;
    for (final it in list) {
      final dup = items.any((e) => e.title == it.title && e.note == it.note && e.date == it.date && e.day == it.day);
      if (!dup) {
        items.add(it);
        n++;
      }
    }
    await _save();
    return n;
  }

  /// Yedek: bütün kayıtlar tek metin olarak
  String exportBackup() => 'SONGUN1:${Item.encodeList(items)}';

  /// Yedekten geri yükle. Geçersizse hata fırlatır.
  Future<int> importBackup(String text) async {
    var t = text.trim();
    if (t.startsWith('SONGUN1:')) t = t.substring(8);
    final list = Item.decodeList(t);
    return addMany(list);
  }

  double monthlyTotal() => items
      .where((e) => e.kind == Kind.abonelik)
      .fold(0.0, (a, e) => a + (e.amount ?? 0));
}
