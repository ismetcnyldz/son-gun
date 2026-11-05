// İlk açılış: 3 sayfalık tanıtım + bildirim izni, ardından deneme ekranı
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'entitlement.dart';
import 'main.dart';
import 'notify.dart';
import 'paywall.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final pc = PageController();
  int page = 0;

  @override
  void dispose() {
    pc.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!kIsWeb) {
      try {
        await Notifier.requestPermission();
      } catch (_) {}
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaywallPage(firstRun: true)));
    await entitlement.finishOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _Slide(
        art: _ArtCountdown(),
        title: 'Son günü sen unut,\ntelefonun unutmasın.',
        text: 'Sigorta, muayene, pasaport, garanti, kart ödemesi… Hepsinin son günü tek yerde.',
      ),
      _Slide(
        art: _ArtScan(),
        title: 'Fotoğrafını çek,\ntarihi biz okuyalım.',
        text: 'Poliçe, ekstre ya da garanti belgesi. Okuma telefonunun içinde yapılır, belgelerin hiçbir yere gönderilmez.',
      ),
      _Slide(
        art: _ArtBell(),
        title: 'Zamanı gelince\nhatırlatalım.',
        text: '30, 7 ve 1 gün kala, son gün sabahı bildirim gelir. Bunun için bildirim izni vermen yeterli.',
      ),
    ];
    final last = page == pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: last ? null : () => pc.animateToPage(pages.length - 1, duration: const Duration(milliseconds: 350), curve: Curves.easeOut),
              child: Text(last ? '' : 'Atla', style: TextStyle(color: C.muted, fontWeight: FontWeight.w700)),
            ),
          ),
          Expanded(
            child: PageView(
              controller: pc,
              onPageChanged: (i) => setState(() => page = i),
              children: pages,
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < pages.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == page ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(color: i == page ? C.accent : C.line, borderRadius: BorderRadius.circular(99)),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: FilledButton(
              onPressed: last ? _finish : () => pc.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOut),
              child: Text(last ? (kIsWeb ? 'Başla' : 'Bildirimlere izin ver ve başla') : 'Devam'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.art, required this.title, required this.text});
  final Widget art;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(height: 240, child: Center(child: art)),
          const SizedBox(height: 28),
          Text(title, textAlign: TextAlign.center, style: display(32)),
          const SizedBox(height: 14),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: C.muted, fontSize: 16, height: 1.45)),
        ]),
      );
}

// ---- Çizimler (uygulamanın kendi parçalarıyla)
class _ArtCountdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget row(IconData i, String t, String d, Color c) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
          child: Row(children: [
            IconBox(icon: i, color: c, size: 36),
            const SizedBox(width: 10),
            Expanded(child: Text(t, style: TextStyle(fontWeight: FontWeight.w800, color: C.ink))),
            Text(d, style: display(22, color: c)),
          ]),
        );
    return SizedBox(
      width: 280,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        row(Icons.credit_card_rounded, 'Kart son ödeme', '3', C.red),
        row(Icons.directions_car_rounded, 'Trafik sigortası', '4', C.red),
        row(Icons.directions_car_rounded, 'Araç muayenesi', '18', C.amber),
        row(Icons.badge_rounded, 'Pasaport', '72', C.green),
      ]),
    );
  }
}

class _ArtScan extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Stack(alignment: Alignment.center, children: [
        Container(
          width: 200,
          height: 130,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF7EC),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final w in [90.0, 160.0, 120.0]) ...[
              Container(width: w, height: 7, decoration: BoxDecoration(color: const Color(0xFFD9D2C3), borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 8),
            ],
            Text('BİTİŞ: 14.12.2026', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 12, color: const Color(0xFF8A1C1C))),
          ]),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 170,
                decoration: BoxDecoration(border: Border.all(color: C.accent, width: 3), borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(99)),
            child: Text('Okundu: 14 Aralık 2026', style: GoogleFonts.manrope(color: C.onAccent, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ),
      ]);
}

class _ArtBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 290,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [C.heroA, C.heroB]),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 46),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
            child: Row(children: [
              IconBox(icon: Icons.directions_car_rounded, color: C.red, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Trafik sigortası', style: TextStyle(fontWeight: FontWeight.w800, color: C.ink)),
                  Text('7 gün kaldı · Son gün 12 Kasım', style: TextStyle(color: C.muted, fontSize: 12)),
                ]),
              ),
            ]),
          ),
        ]),
      );
}
