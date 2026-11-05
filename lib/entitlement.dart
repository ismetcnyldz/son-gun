// Abonelik / deneme durumu.
// Şimdilik deneme süresi telefonda tutulur; mağaza ödeme sistemi (RevenueCat) eklenince
// `subscribed` gerçek satın alma bilgisinden gelecek.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'billing.dart';

class Entitlement extends ChangeNotifier {
  static const trialDays = 30;
  static const monthlyPrice = '₺49,99';
  static const yearlyPrice = '₺399';

  /// Ödeme sistemi bağlı mı? (mağaza anahtarı verilince true olur)
  static bool get billingReady => Billing.ready;

  DateTime? trialStart;
  bool subscribed = false;
  bool onboarded = false;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final t = p.getString('trial_start');
    trialStart = t == null ? null : DateTime.tryParse(t);
    subscribed = p.getBool('subscribed') ?? false;
    onboarded = p.getBool('onboarded') ?? false;
    notifyListeners();
  }

  Future<void> finishOnboarding() async {
    onboarded = true;
    final p = await SharedPreferences.getInstance();
    await p.setBool('onboarded', true);
    notifyListeners();
  }

  Future<void> startTrial() async {
    trialStart ??= DateTime.now();
    final p = await SharedPreferences.getInstance();
    await p.setString('trial_start', trialStart!.toIso8601String());
    notifyListeners();
  }

  Future<void> setSubscribed(bool v) async {
    if (subscribed == v) return;
    subscribed = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool('subscribed', v);
    notifyListeners();
  }

  bool get trialStarted => trialStart != null;

  int get trialDaysLeft {
    if (trialStart == null) return 0;
    final left = trialDays - DateTime.now().difference(trialStart!).inDays;
    return left < 0 ? 0 : left;
  }

  bool get inTrial => !subscribed && trialStarted && trialDaysLeft > 0;

  /// Yeni kayıt ve hatırlatmalar için yetki
  bool get active => subscribed || inTrial;
}

final entitlement = Entitlement();
