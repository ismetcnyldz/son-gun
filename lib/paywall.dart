// Abonelik ekranı: 1 ay ücretsiz deneme
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'entitlement.dart';
import 'main.dart';
import 'models.dart';

class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key, this.firstRun = false});
  final bool firstRun;
  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  bool yearly = true;
  bool busy = false;

  Future<void> _start() async {
    setState(() => busy = true);
    // Mağaza ödeme sistemi bağlanınca burada gerçek satın alma başlayacak.
    await entitlement.startTrial();
    await store.refreshReminders();
    if (!mounted) return;
    setState(() => busy = false);
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text('Deneme başladı: ${Entitlement.trialDays} gün boyunca her şey açık.'),
    ));
  }

  void _toast(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t), behavior: SnackBarBehavior.floating));

  Widget _feature(IconData i, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          IconBox(icon: i, color: C.accent, size: 36),
          const SizedBox(width: 12),
          Expanded(child: Text(t, style: TextStyle(fontWeight: FontWeight.w700, color: C.ink, fontSize: 15))),
        ]),
      );

  Widget _plan({required bool isYearly, required String title, required String price, required String sub, String? badge}) {
    final sel = yearly == isYearly;
    return GestureDetector(
      onTap: () => setState(() => yearly = isYearly),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: sel ? C.accent : C.line, width: sel ? 2 : 1),
        ),
        child: Row(children: [
          Icon(sel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: sel ? C.accent : C.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: C.ink)),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(99)),
                    child: Text(badge, style: GoogleFonts.manrope(color: C.onAccent, fontSize: 10.5, fontWeight: FontWeight.w800)),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(color: C.muted, fontSize: 12.5)),
            ]),
          ),
          Text(price, style: display(20)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expired = entitlement.trialStarted && !entitlement.active;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: Icon(Icons.close_rounded, color: C.muted),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(colors: [C.heroA, C.heroB], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(expired ? 'Deneme süren bitti' : 'İlk ay bizden', style: GoogleFonts.manrope(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Text(expired ? 'Hatırlatmalar durdu. Devam etmek için abone ol.' : '${Entitlement.trialDays} gün ücretsiz,\nsonra istersen devam.',
                        style: display(28, color: Colors.white)),
                  ]),
                ),
                const SizedBox(height: 20),
                _feature(Icons.all_inclusive_rounded, 'Sınırsız belge, garanti ve ödeme'),
                _feature(Icons.document_scanner_rounded, 'Fotoğraftan otomatik tarih okuma'),
                _feature(Icons.notifications_active_rounded, '30, 7, 1 gün kala hatırlatmalar'),
                _feature(Icons.auto_awesome_rounded, 'Türkiye takvimi: muayene, MTV, emlak vergisi'),
                _feature(Icons.lock_rounded, 'Uygulama kilidi ve yedekleme'),
                const SizedBox(height: 8),
                _plan(isYearly: true, title: 'Yıllık', price: Entitlement.yearlyPrice, sub: 'Ayda ₺33\'e gelir · ilk ay ücretsiz', badge: 'En avantajlı'),
                _plan(isYearly: false, title: 'Aylık', price: Entitlement.monthlyPrice, sub: 'İlk ay ücretsiz'),
                const SizedBox(height: 6),
                FilledButton(
                  onPressed: busy ? null : _start,
                  child: Text(expired ? 'Abone ol' : '${Entitlement.trialDays} gün ücretsiz başla'),
                ),
                const SizedBox(height: 10),
                Text(
                  'Deneme bitmeden istediğin an iptal edersen hiçbir ücret alınmaz. Abonelik, iptal edilmedikçe '
                  '${yearly ? 'yıllık ${Entitlement.yearlyPrice}' : 'aylık ${Entitlement.monthlyPrice}'} olarak otomatik yenilenir. '
                  'Abone olmasan da kayıtların silinmez.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: C.muted, fontSize: 12, height: 1.4),
                ),
                if (!Entitlement.billingReady && !storeShots) ...[
                  const SizedBox(height: 8),
                  Text('Test sürümü: şu an ödeme alınmaz.', textAlign: TextAlign.center, style: TextStyle(color: C.amber, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  TextButton(onPressed: () => _toast('Satın alımlar, uygulama mağazada yayınlanınca geri yüklenebilecek.'), child: const Text('Satın alımları geri yükle')),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
