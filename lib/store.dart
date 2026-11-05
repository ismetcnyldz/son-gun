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

  /// Son günü olan kayıtlar, en yakından uzağa
  List<Item> upcoming() {
    final l = items.where((e) => e.nextDue() != null).toList();
    l.sort((a, b) => a.nextDue()!.compareTo(b.nextDue()!));
    return l;
  }

  double monthlyTotal() => items
      .where((e) => e.kind == Kind.abonelik)
      .fold(0.0, (a, e) => a + (e.amount ?? 0));
}
