// Mağaza ödemeleri (RevenueCat). Anahtarlar derleme sırasında verilir:
//   --dart-define=RC_ANDROID_KEY=... --dart-define=RC_IOS_KEY=...
// Anahtar yoksa (şimdilik) ödeme kapalıdır, uygulama deneme modunda çalışır.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'entitlement.dart';

class Billing {
  static const _androidKey = String.fromEnvironment('RC_ANDROID_KEY');
  static const _iosKey = String.fromEnvironment('RC_IOS_KEY');

  /// RevenueCat panelinde açılacak yetkinin adı
  static const entitlementId = 'premium';

  static bool ready = false;
  static Offering? offering;

  static String get _key => defaultTargetPlatform == TargetPlatform.iOS ? _iosKey : _androidKey;

  static Future<void> init() async {
    if (kIsWeb || _key.isEmpty) return;
    try {
      await Purchases.configure(PurchasesConfiguration(_key));
      ready = true;
      Purchases.addCustomerInfoUpdateListener(_apply);
      _apply(await Purchases.getCustomerInfo());
      offering = (await Purchases.getOfferings()).current;
    } catch (e) {
      debugPrint('Billing init: $e');
    }
  }

  static void _apply(CustomerInfo info) => entitlement.setSubscribed(info.entitlements.active.containsKey(entitlementId));

  static Package? package(bool yearly) => yearly ? offering?.annual : offering?.monthly;

  /// Mağazadaki gerçek fiyat (yoksa null)
  static String? price(bool yearly) => package(yearly)?.storeProduct.priceString;

  /// Satın al. true: abonelik aktif. false: vazgeçildi. Hata: mesaj fırlatır.
  static Future<bool> buy(bool yearly) async {
    if (!ready) throw 'Ödeme sistemi henüz hazır değil.';
    if (offering == null) {
      try {
        offering = (await Purchases.getOfferings()).current;
      } catch (_) {}
    }
    final p = package(yearly);
    if (p == null) throw 'Paketler yüklenemedi. İnternet bağlantını kontrol et.';
    try {
      final info = await Purchases.purchasePackage(p);
      _apply(info);
      return entitlement.subscribed;
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) == PurchasesErrorCode.purchaseCancelledError) return false;
      throw e.message ?? 'Satın alma tamamlanamadı.';
    }
  }

  static Future<bool> restore() async {
    if (!ready) throw 'Ödeme sistemi henüz hazır değil.';
    final info = await Purchases.restorePurchases();
    _apply(info);
    return entitlement.subscribed;
  }
}
