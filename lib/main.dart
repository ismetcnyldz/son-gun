import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'billing.dart';
import 'calendar.dart';
import 'entitlement.dart';
import 'lock.dart';
import 'models.dart';
import 'notify.dart';
import 'onboarding.dart';
import 'ocr.dart';
import 'paywall.dart';
import 'settings_page.dart';
import 'sms.dart';
import 'store.dart';
import 'turkey.dart';

final store = Store();

/// Tema tercihi: sistem, açık, koyu
final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

Future<void> loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final v = prefs.getString('theme_mode');
  themeMode.value = ThemeMode.values.firstWhere((m) => m.name == v, orElse: () => ThemeMode.system);
}

Future<void> setThemeMode(ThemeMode m) async {
  themeMode.value = m;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('theme_mode', m.name);
}

Future<void> main() async {
  await runZonedGuarded(_start, (e, st) {
    debugPrint('HATA: $e\n$st');
  });
}

Future<void> _start() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (d) => Material(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: SelectableText('Ekran hatası:\n${d.exceptionAsString()}', style: TextStyle(fontSize: 12)),
        ),
      );
  if (!kIsWeb) {
    try {
      await Notifier.init();
    } catch (_) {/* bildirim izni yoksa uygulama yine açılsın */}
  }
  try {
    await loadThemeMode();
    await loadLockSetting();
    await entitlement.load();
    await Notifier.loadTime();
    if (!kIsWeb && entitlement.onboarded) await Notifier.requestPermission();
  } catch (_) {}
  try {
    await store.load();
  } catch (e) {
    debugPrint('Kayıtlar yüklenemedi: $e');
  }
  runApp(VakitbilApp());
  // Ödeme sistemi açılışı geciktirmesin; abonelik durumu değişince hatırlatmalar yeniden kurulur
  var wasActive = entitlement.active;
  entitlement.addListener(() {
    if (entitlement.active != wasActive) {
      wasActive = entitlement.active;
      store.refreshReminders();
    }
  });
  unawaited(Billing.init());
}

// ---------------------------------------------------------------- Tasarım
class Pal {
  const Pal({required this.bg, required this.card, required this.card2, required this.ink, required this.muted,
      required this.line, required this.accent, required this.onAccent, required this.onInk,
      required this.red, required this.amber, required this.green});
  final Color bg, card, card2, ink, muted, line, accent, onAccent, onInk, red, amber, green;
}

const lightPal = Pal(
  bg: Color(0xFFF3F1EC), card: Color(0xFFFFFDF9), card2: Color(0xFFEBE7DF), ink: Color(0xFF22262B),
  muted: Color(0xFF6B6F75), line: Color(0xFFDDD8CE), accent: Color(0xFF2F5D62), onAccent: Color(0xFFFFFFFF),
  onInk: Color(0xFFFFFFFF), red: Color(0xFFC2412D), amber: Color(0xFFC98A12), green: Color(0xFF3C7D4F),
);

const darkPal = Pal(
  bg: Color(0xFF15181B), card: Color(0xFF1F2327), card2: Color(0xFF2A2F34), ink: Color(0xFFECE8E0),
  muted: Color(0xFFA3A7AD), line: Color(0xFF353A40), accent: Color(0xFF7DC1C6), onAccent: Color(0xFF0F1A1C),
  onInk: Color(0xFF15181B), red: Color(0xFFEF8069), amber: Color(0xFFE9B85A), green: Color(0xFF82C795),
);

/// Geçerli tema renkleri. Tema değişince bütün ekran yeniden çizilir.
class C {
  static Pal p = lightPal;
  static Color get bg => p.bg;
  static Color get card => p.card;
  static Color get card2 => p.card2;
  static Color get ink => p.ink;
  static Color get muted => p.muted;
  static Color get line => p.line;
  static Color get accent => p.accent;
  static Color get onAccent => p.onAccent;
  static Color get onInk => p.onInk;
  static Color get red => p.red;
  static Color get amber => p.amber;
  static Color get green => p.green;
  static const heroA = Color(0xFF2F5D62);
  static const heroB = Color(0xFF1C3B3F);
}

TextStyle display(double size, {Color? color, FontWeight w = FontWeight.w700}) =>
    GoogleFonts.fraunces(fontSize: size, fontWeight: w, color: color ?? C.ink, height: 1.05, letterSpacing: -0.4);

class VakitbilApp extends StatefulWidget {
  VakitbilApp({super.key});
  @override
  State<VakitbilApp> createState() => _VakitbilAppState();
}

class _VakitbilAppState extends State<VakitbilApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    themeMode.addListener(_changed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    themeMode.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  void didChangePlatformBrightness() => setState(() {});

  bool get _dark => switch (themeMode.value) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
      };

  @override
  Widget build(BuildContext context) {
    final dark = _dark;
    C.p = dark ? darkPal : lightPal;
    final base = ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: C.heroA,
        brightness: dark ? Brightness.dark : Brightness.light,
        surface: C.card,
        primary: C.accent,
        onPrimary: C.onAccent,
      ),
      scaffoldBackgroundColor: C.bg,
    );
    return MaterialApp(
      key: ValueKey(dark),
      title: appName,
      debugShowCheckedModeBanner: false,
      locale: Locale('tr'),
      supportedLocales: [Locale('tr')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: base.copyWith(
        textTheme: GoogleFonts.manropeTextTheme(base.textTheme).apply(bodyColor: C.ink, displayColor: C.ink),
        appBarTheme: AppBarTheme(backgroundColor: C.bg, foregroundColor: C.ink, surfaceTintColor: Colors.transparent, elevation: 0),
        snackBarTheme: SnackBarThemeData(backgroundColor: C.ink, contentTextStyle: TextStyle(color: C.onInk)),
        dividerColor: C.line,
        cardTheme: CardThemeData(
          color: C.card,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: C.line)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: C.card,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: C.line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: C.line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: C.accent, width: 2)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: C.card,
          indicatorColor: C.accent.withValues(alpha: 0.14),
          labelTextStyle: WidgetStatePropertyAll(GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: C.accent,
            foregroundColor: C.onAccent,
            minimumSize: Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: C.ink,
            minimumSize: Size.fromHeight(52),
            side: BorderSide(color: C.line),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      home: ListenableBuilder(
        listenable: entitlement,
        builder: (_, __) => entitlement.onboarded ? LockGate(child: Shell()) : OnboardingPage(),
      ),
    );
  }
}

// ---------------------------------------------------------------- Simgeler ve renkler
IconData iconFor(Item it) {
  final t = trLower('${it.title} ${it.note}');
  bool has(List<String> w) => w.any(t.contains);
  if (it.kind == Kind.kart) return Icons.credit_card_rounded;
  if (has(['trafik', 'kasko', 'muayene', 'mtv', 'plaka', 'araç', 'arac'])) return Icons.directions_car_rounded;
  if (has(['dask', 'konut', 'kira', 'aidat', 'internet', 'elektrik', 'doğalgaz', 'su fatura'])) return Icons.home_rounded;
  if (has(['pasaport', 'ehliyet', 'kimlik'])) return Icons.badge_rounded;
  if (has(['sağlık', 'saglik', 'ilaç', 'ilac', 'aşı', 'asi'])) return Icons.favorite_rounded;
  if (has(['netflix', 'spotify', 'youtube', 'disney', 'exxen', 'blutv', 'prime'])) return Icons.play_circle_fill_rounded;
  if (has(['telefon', 'gsm', 'hat'])) return Icons.smartphone_rounded;
  if (has(['spor', 'gym'])) return Icons.fitness_center_rounded;
  return switch (it.kind) {
    Kind.belge => Icons.description_rounded,
    Kind.garanti => Icons.verified_user_rounded,
    Kind.kart => Icons.credit_card_rounded,
    Kind.abonelik => Icons.autorenew_rounded,
    Kind.cek => Icons.receipt_long_rounded,
    Kind.diger => Icons.event_rounded,
  };
}

IconData kindIcon(Kind k) => switch (k) {
      Kind.belge => Icons.description_rounded,
      Kind.garanti => Icons.verified_user_rounded,
      Kind.kart => Icons.credit_card_rounded,
      Kind.abonelik => Icons.autorenew_rounded,
      Kind.cek => Icons.receipt_long_rounded,
      Kind.diger => Icons.event_rounded,
    };

Color urgency(int? days) {
  if (days == null) return C.muted;
  if (days <= 7) return C.red;
  if (days <= 30) return C.amber;
  return C.green;
}

final _weekdays = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
String todayText() {
  final d = DateTime.now();
  return '${d.day} ${trMonths[d.month - 1]} ${_weekdays[d.weekday - 1]}';
}

Future<void> openEditor(BuildContext context, {Item? item, Kind? kind}) async {
  if (item == null && !entitlement.active) {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => PaywallPage()));
    if (ok != true || !context.mounted) return;
  }
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorPage(item: item, initialKind: kind)));
}

// ---------------------------------------------------------------- İskelet
class Shell extends StatefulWidget {
  Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [HomePage(onTab: (i) => setState(() => tab = i)), PaymentsPage(), SmsPage()];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 640), child: pages[tab])),
      ),
      floatingActionButton: tab == 2
          ? null
          : FloatingActionButton.extended(
              backgroundColor: C.ink,
              foregroundColor: C.onInk,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              onPressed: () => openEditor(context, kind: tab == 1 ? Kind.kart : null),
              icon: Icon(Icons.add_rounded),
              label: Text('Ekle', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today_rounded), label: 'Ana sayfa'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Ödemeler'),
          NavigationDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield_rounded), label: 'SMS Kontrol'),
        ],
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  PageHeader({super.key, required this.title, this.sub, this.action});
  final String title;
  final String? sub;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 12, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (sub != null) Text(sub!.toUpperCase(), style: GoogleFonts.manrope(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: C.muted)),
              SizedBox(height: 4),
              Text(title, style: display(34)),
            ]),
          ),
          action ?? SettingsButton(),
        ]),
      );
}

/// Ayarlar düğmesi
class SettingsButton extends StatelessWidget {
  SettingsButton({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Ayarlar',
        icon: Icon(Icons.settings_rounded, color: C.ink),
        style: IconButton.styleFrom(backgroundColor: C.card, side: BorderSide(color: C.line)),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
      );
}

/// Tema seçimi: Sistem / Açık / Koyu
class ThemeButton extends StatelessWidget {
  ThemeButton({super.key});

  IconData get _icon => switch (themeMode.value) {
        ThemeMode.dark => Icons.dark_mode_rounded,
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.system => Icons.brightness_auto_rounded,
      };

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Tema',
        icon: Icon(_icon, color: C.ink),
        style: IconButton.styleFrom(backgroundColor: C.card, side: BorderSide(color: C.line)),
        onPressed: () => showModalBottomSheet(
          context: context,
          backgroundColor: C.card,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Görünüm', style: display(22)),
                SizedBox(height: 12),
                for (final (m, t, i) in [
                  (ThemeMode.system, 'Telefonla aynı', Icons.brightness_auto_rounded),
                  (ThemeMode.light, 'Açık tema', Icons.light_mode_rounded),
                  (ThemeMode.dark, 'Koyu tema', Icons.dark_mode_rounded),
                ])
                  Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: themeMode.value == m ? C.accent.withValues(alpha: 0.14) : C.card2,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        leading: Icon(i, color: C.accent),
                        title: Text(t, style: TextStyle(fontWeight: FontWeight.w700, color: C.ink)),
                        trailing: themeMode.value == m ? Icon(Icons.check_circle_rounded, color: C.accent) : null,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          setThemeMode(m);
                        },
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 22, 20, 10),
        child: Row(children: [
          Expanded(child: Text(text, style: display(21, w: FontWeight.w600))),
          if (trailing != null) trailing!,
        ]),
      );
}

// ---------------------------------------------------------------- Ana sayfa
class HomePage extends StatefulWidget {
  HomePage({super.key, required this.onTab});
  final ValueChanged<int> onTab;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Kind? filter;
  String query = '';
  final searchCtl = TextEditingController();

  @override
  void dispose() {
    searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, entitlement]),
      builder: (context, _) {
        final all = store.upcoming();
        final found = store.search(query);
        final list = filter == null ? found : found.where((e) => e.kind == filter).toList();
        final soon = all.where((e) => (e.daysLeft() ?? 999) <= 30).length;
        final week = all.where((e) => (e.daysLeft() ?? 999) <= 7).length;
        final monthPay = all
            .where((e) => e.kind.monthly || (e.daysLeft() ?? 999) <= 31)
            .where((e) => (e.daysLeft() ?? 999) <= 31)
            .fold<double>(0, (a, e) => a + (e.amount ?? 0));
        return ListView(
          padding: EdgeInsets.only(bottom: 110),
          children: [
            PageHeader(title: appName, sub: todayText()),
            if (!entitlement.subscribed) Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 10), child: TrialBanner()),
            Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _hero(soon, week)),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: StatTile(value: fmtMoney(monthPay), label: '31 gün içinde ödenecek', icon: Icons.payments_rounded)),
                SizedBox(width: 10),
                Expanded(child: StatTile(value: '${all.length}', label: 'Kayıtlı belge ve ödeme', icon: Icons.folder_rounded)),
              ]),
            ),
            if (all.isEmpty) ...[
              SectionTitle('Başlayalım'),
              _onboarding(),
            ] else ...[
              SectionTitle('Yaklaşanlar', trailing: Text('${list.length} kayıt', style: TextStyle(color: C.muted, fontWeight: FontWeight.w600))),
              if (all.length >= 4)
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: TextField(
                    controller: searchCtl,
                    onChanged: (v) => setState(() => query = v),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Ara: plaka, banka, ürün…',
                      prefixIcon: Icon(Icons.search_rounded, color: C.muted),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(Icons.close_rounded, color: C.muted),
                              onPressed: () => setState(() {
                                searchCtl.clear();
                                query = '';
                              }),
                            ),
                    ),
                  ),
                ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _chip('Hepsi', null),
                    for (final k in Kind.values) _chip(k.label, k),
                  ],
                ),
              ),
              SizedBox(height: 8),
              if (list.isEmpty)
                Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: Text(query.isEmpty ? 'Bu kategoride kayıt yok.' : '"$query" ile eşleşen kayıt yok.', style: TextStyle(color: C.muted))),
                ),
              for (final it in list) Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 4), child: ItemCard(item: it)),
            ],
            SectionTitle('Her şey'),
            Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _grid(all)),
          ],
        );
      },
    );
  }

  Widget _hero(int soon, int week) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(colors: [C.heroA, C.heroB], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: C.heroA.withValues(alpha: 0.25), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$soon', style: display(56, color: Colors.white)),
            SizedBox(height: 6),
            Text(
              soon == 0 ? 'Önümüzdeki 30 günde süresi dolan bir şey yok. İçin rahat olsun.' : 'kaydın süresi 30 gün içinde doluyor',
              style: GoogleFonts.manrope(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, fontWeight: FontWeight.w600),
            ),
            if (week > 0) ...[
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(99)),
                child: Text('$week tanesi bu hafta', style: GoogleFonts.manrope(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ]),
        ),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(18)),
          child: Icon(Icons.notifications_active_rounded, color: Colors.white, size: 30),
        ),
      ]),
    );
  }

  Widget _chip(String t, Kind? k) {
    final sel = filter == k;
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => filter = k),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? C.ink : C.card,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: sel ? C.ink : C.line),
          ),
          child: Text(t, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: sel ? C.onInk : C.ink)),
        ),
      ),
    );
  }

  Widget _onboarding() {
    Widget step(IconData i, String t, String s, Kind k) => Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => openEditor(context, kind: k),
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Row(children: [
                  IconBox(icon: i, color: C.accent),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      SizedBox(height: 2),
                      Text(s, style: TextStyle(color: C.muted, fontSize: 13)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: C.muted),
                ]),
              ),
            ),
          ),
        );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        step(Icons.directions_car_rounded, 'Aracının belgelerini ekle', 'Trafik sigortası, kasko, muayene', Kind.belge),
        step(Icons.credit_card_rounded, 'Kart son ödeme günlerini ekle', 'Sadece banka ve gün; kart numarası istenmez', Kind.kart),
        step(Icons.verified_user_rounded, 'Garanti belgelerini sakla', 'Telefon, beyaz eşya, elektronik', Kind.garanti),
        step(Icons.autorenew_rounded, 'Aboneliklerini gir', 'Aylık toplamını gör', Kind.abonelik),
      ]),
    );
  }

  Widget _grid(List<Item> all) {
    final cells = [
      (Kind.belge, 'Belgeler'),
      (Kind.garanti, 'Garantiler'),
      (Kind.kart, 'Kartlar'),
      (Kind.abonelik, 'Abonelikler'),
      (Kind.cek, 'Çek / senet'),
      (Kind.diger, 'Diğer'),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.98,
      children: [
        for (final (k, name) in cells)
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                if (k.monthly || k == Kind.cek) {
                  widget.onTab(1);
                } else {
                  setState(() => filter = k);
                }
              },
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconBox(icon: kindIcon(k), color: C.accent, size: 42),
                SizedBox(height: 8),
                Text(name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                Text('${all.where((e) => e.kind == k).length} kayıt', style: TextStyle(color: C.muted, fontSize: 11)),
              ]),
            ),
          ),
      ],
    );
  }
}

/// Deneme / abonelik durumu şeridi
class TrialBanner extends StatelessWidget {
  TrialBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final expired = entitlement.trialStarted && !entitlement.active;
    final notStarted = !entitlement.trialStarted;
    final c = expired ? C.red : C.accent;
    final text = expired
        ? 'Deneme bitti, hatırlatmalar durdu. Devam etmek için abone ol.'
        : notStarted
            ? '${Entitlement.trialDays} gün ücretsiz denemeyi başlat'
            : 'Ücretsiz deneme: ${entitlement.trialDaysLeft} gün kaldı';
    return Material(
      color: c.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaywallPage())),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Icon(expired ? Icons.error_outline_rounded : Icons.workspace_premium_rounded, color: c, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(color: C.ink, fontWeight: FontWeight.w700, fontSize: 13))),
            Icon(Icons.chevron_right_rounded, color: c),
          ]),
        ),
      ),
    );
  }
}

class IconBox extends StatelessWidget {
  IconBox({super.key, required this.icon, required this.color, this.size = 46});
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(size * 0.3)),
        child: Icon(icon, color: color, size: size * 0.5),
      );
}

class StatTile extends StatelessWidget {
  StatTile({super.key, required this.value, required this.label, required this.icon, this.color});
  final String value;
  final String label;
  final IconData icon;
  final Color? color;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20, color: C.muted),
            SizedBox(height: 10),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: display(24, color: color ?? C.ink))),
            SizedBox(height: 2),
            Text(label, style: TextStyle(color: C.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class ItemCard extends StatelessWidget {
  ItemCard({super.key, required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final d = item.daysLeft();
    final due = item.nextDue();
    final c = urgency(d);
    final sub = [
      if (item.note.isNotEmpty) item.note,
      if (due != null) fmtDate(due),
    ].join(' · ');
    final total = item.kind.monthly ? 30 : 60;
    final progress = d == null ? 0.0 : (1 - (d.clamp(0, total) / total)).toDouble();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openEditor(context, item: item),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 5, color: (d ?? 999) <= 30 ? c : Colors.transparent),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 14, 12),
                child: Column(children: [
                  Row(children: [
                    IconBox(icon: iconFor(item), color: c == C.green ? C.accent : c),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        SizedBox(height: 2),
                        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: C.muted, fontSize: 12.5)),
                        if (item.amount != null) ...[
                          SizedBox(height: 4),
                          Text(fmtMoney(item.amount!), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        ],
                      ]),
                    ),
                    if (d != null)
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(d < 0 ? '${-d}' : (d == 0 ? '!' : '$d'), style: display(28, color: c)),
                        Text(d < 0 ? 'gün geçti' : (d == 0 ? 'bugün' : 'gün kaldı'), style: TextStyle(fontSize: 11, color: C.muted, fontWeight: FontWeight.w600)),
                      ]),
                  ]),
                  SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: progress, minHeight: 4, color: c, backgroundColor: C.card2),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Ödemeler
class PaymentsPage extends StatelessWidget {
  PaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final cards = store.upcoming().where((e) => e.kind == Kind.kart).toList();
        final cheques = store.upcoming().where((e) => e.kind == Kind.cek).toList();
        final chequeTotal = cheques.where((e) => (e.daysLeft() ?? 999) <= 31).fold<double>(0, (a, e) => a + (e.amount ?? 0));
        final subs = store.upcoming().where((e) => e.kind == Kind.abonelik).toList();
        final total = store.monthlyTotal();
        final cardTotal = cards.fold<double>(0, (a, e) => a + (e.amount ?? 0));
        return ListView(
          padding: EdgeInsets.only(bottom: 110),
          children: [
            PageHeader(title: 'Ödemeler', sub: 'Kartlar, abonelikler, çekler'),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: StatTile(value: fmtMoney(total), label: 'Aylık abonelik', icon: Icons.autorenew_rounded)),
                SizedBox(width: 10),
                Expanded(child: StatTile(value: fmtMoney(total * 12), label: 'Yıllık abonelik', icon: Icons.calendar_month_rounded)),
              ]),
            ),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: StatTile(value: fmtMoney(cardTotal), label: 'Kart ekstreleri toplamı', icon: Icons.credit_card_rounded),
            ),
            SectionTitle('Kartlar', trailing: TextButton.icon(onPressed: () => openEditor(context, kind: Kind.kart), icon: Icon(Icons.add_rounded, size: 18), label: Text('Kart ekle'))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Icon(Icons.lock_rounded, size: 18, color: C.accent),
                  SizedBox(width: 10),
                  Expanded(child: Text('Kart numarası, CVV veya şifre asla istenmez. Sadece banka adı ve son ödeme günü tutulur.', style: TextStyle(fontSize: 12.5))),
                ]),
              ),
            ),
            SizedBox(height: 8),
            if (cards.isEmpty) _Empty('Henüz kart eklenmedi.'),
            for (final c in cards) Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 4), child: ItemCard(item: c)),
            SectionTitle('Abonelikler', trailing: TextButton.icon(onPressed: () => openEditor(context, kind: Kind.abonelik), icon: Icon(Icons.add_rounded, size: 18), label: Text('Abonelik ekle'))),
            if (subs.isEmpty) _Empty('Henüz abonelik eklenmedi.'),
            for (final s in subs) Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 4), child: ItemCard(item: s)),
            SectionTitle('Çek / senet', trailing: TextButton.icon(onPressed: () => openEditor(context, kind: Kind.cek), icon: Icon(Icons.add_rounded, size: 18), label: Text('Ekle'))),
            if (cheques.isEmpty)
              _Empty('Çek, senet ya da taksit ödemesi yok.')
            else
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text('31 gün içinde: ${fmtMoney(chequeTotal)}', style: TextStyle(color: C.muted, fontWeight: FontWeight.w700)),
              ),
            for (final c in cheques) Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 4), child: ItemCard(item: c)),
          ],
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Text(text, style: TextStyle(color: C.muted)),
      );
}

// ---------------------------------------------------------------- SMS Kontrol
class SmsPage extends StatefulWidget {
  SmsPage({super.key});
  @override
  State<SmsPage> createState() => _SmsPageState();
}

class _SmsPageState extends State<SmsPage> {
  final ctl = TextEditingController();
  SmsVerdict? v;

  static const _samples = [
    'Sayin vatandas, hakkinizda icra takibi baslatilmistir. Dosyanizin kapatilmasi icin 24 saat icinde odeme yapiniz: http://e-devlet-icra-odeme.com/dosya',
    'Gonderiniz yola cikti. Takip no: 7290045812. Detay icin: https://www.yurticikargo.com',
  ];

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  void _check() {
    if (ctl.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => v = checkSms(ctl.text));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(bottom: 40),
      children: [
        PageHeader(title: 'Bu SMS sahte mi?', sub: 'Dolandırıcılık kontrolü'),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Şüphelendiğin mesajı yapıştır. İçindeki linke tıklamadan kontrol edelim.', style: TextStyle(color: C.muted)),
            SizedBox(height: 12),
            TextField(
              controller: ctl,
              minLines: 5,
              maxLines: 9,
              decoration: InputDecoration(
                hintText: 'Mesajı buraya yapıştır',
                suffixIcon: IconButton(
                  tooltip: 'Yapıştır',
                  icon: Icon(Icons.content_paste_rounded),
                  onPressed: () async {
                    final d = await Clipboard.getData('text/plain');
                    if (d?.text != null) setState(() => ctl.text = d!.text!);
                  },
                ),
              ),
            ),
            SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => setState(() { ctl.text = _samples[0]; v = null; }), child: Text('Örnek: sahte icra'))),
              SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () => setState(() { ctl.text = _samples[1]; v = null; }), child: Text('Örnek: kargo'))),
            ]),
            SizedBox(height: 10),
            FilledButton.icon(onPressed: _check, icon: Icon(Icons.search_rounded), label: Text('Kontrol et')),
            SizedBox(height: 16),
            if (v != null) _result(v!),
          ]),
        ),
      ],
    );
  }

  Widget _result(SmsVerdict v) {
    final c = v.risky ? C.red : (v.reasons.isEmpty ? C.green : C.amber);
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        border: Border.all(color: c.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(v.risky ? Icons.gpp_bad_rounded : Icons.gpp_good_rounded, color: c, size: 30),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              v.risky ? 'Büyük ihtimalle dolandırıcılık' : (v.reasons.isEmpty ? 'Şüpheli bir işaret bulunmadı' : 'Dikkatli ol'),
              style: display(21, color: c),
            ),
          ),
        ]),
        SizedBox(height: 12),
        for (final r in v.reasons)
          Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.circle, size: 6, color: c),
              SizedBox(width: 8),
              Expanded(child: Text(r, style: TextStyle(fontSize: 13.5, height: 1.35))),
            ]),
          ),
        SizedBox(height: 6),
        Text(
          v.risky
              ? 'Linke tıklama, ödeme yapma, kod paylaşma. Borcun olup olmadığını e-Devlet\'ten kendin kontrol et.'
              : 'Yine de emin değilsen linke tıklamak yerine kurumun kendi uygulamasından kontrol et.',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Ekle / Düzenle
class EditorPage extends StatefulWidget {
  EditorPage({super.key, this.item, this.initialKind});
  final Item? item;
  final Kind? initialKind;
  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late Kind kind;
  final title = TextEditingController();
  final note = TextEditingController();
  final amount = TextEditingController();
  DateTime? date;
  int? day;
  String? photo;
  bool scanning = false;
  bool confirmDelete = false;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    kind = it?.kind ?? widget.initialKind ?? Kind.belge;
    title.text = it?.title ?? '';
    note.text = it?.note ?? '';
    amount.text = it?.amount == null ? '' : it!.amount!.toStringAsFixed(2).replaceAll('.', ',');
    date = it?.date;
    day = it?.day;
    photo = it?.photo;
    title.addListener(_onText);
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    amount.dispose();
    super.dispose();
  }

  Future<void> _takePhoto(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, imageQuality: 85, maxWidth: 2000);
    if (x == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = '${dir.path}/belge_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(x.path).copy(dest);
    setState(() {
      photo = dest;
      scanning = true;
    });
    try {
      final r = await scanImage(dest);
      if (!mounted) return;
      setState(() {
        if (r.kind != null) kind = r.kind!;
        if (r.title != null && title.text.trim().isEmpty) title.text = r.title!;
        if (kind.monthly) {
          day = r.day ?? r.date?.day ?? day;
        } else if (r.date != null) {
          date = r.date;
        }
        if (r.amount != null) amount.text = r.amount!.toStringAsFixed(2).replaceAll('.', ',');
      });
      final found = r.date != null || r.day != null;
      _toast(found
          ? 'Okundu: ${r.title ?? 'belge'}${r.date != null ? ' · ${fmtDate(r.date!)}' : ''}. Kontrol edip kaydet.'
          : 'Tarih okunamadı. Tarihi elle seçebilirsin.');
    } catch (_) {
      if (mounted) _toast('Fotoğraf okunamadı. Bilgileri elle girebilirsin.');
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: date ?? now.add(Duration(days: 30)),
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 15),
      helpText: 'Son günü seç',
    );
    if (d != null) setState(() => date = d);
  }

  Future<void> _save() async {
    if (title.text.trim().isEmpty) return _toast('Bir başlık yaz (örneğin "Trafik sigortası").');
    if (kind.monthly && day == null) return _toast('Ayın hangi günü olduğunu seç.');
    if (!kind.monthly && date == null) return _toast('Son günü seç.');
    final it = Item(
      id: widget.item?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      kind: kind,
      title: title.text.trim(),
      note: note.text.trim(),
      date: kind.monthly ? null : date,
      day: kind.monthly ? day : null,
      amount: double.tryParse(amount.text.replaceAll('.', '').replaceAll(',', '.').replaceAll('₺', '').trim()),
      photo: photo,
    );
    await store.upsert(it);
    if (mounted) Navigator.of(context).pop();
  }

  void _toast(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t), behavior: SnackBarBehavior.floating));

  Future<void> _addCalendar() async {
    if (title.text.trim().isEmpty) return _toast('Önce bir başlık yaz.');
    final it = Item(id: '', kind: kind, title: title.text.trim(), note: note.text.trim(), date: kind.monthly ? null : date, day: kind.monthly ? day : null,
        amount: double.tryParse(amount.text.replaceAll('.', '').replaceAll(',', '.').replaceAll('₺', '').trim()));
    try {
      await addToCalendar(it);
    } catch (_) {
      _toast('Takvim açılamadı.');
    }
  }

  Widget _label(String t) => Padding(
        padding: EdgeInsets.only(top: 20, bottom: 8),
        child: Text(t.toUpperCase(), style: GoogleFonts.manrope(fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w800, color: C.muted)),
      );

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    final sugg = presets.where((p) => p.kind == kind).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Kaydı düzenle' : 'Yeni kayıt', style: display(22)),
        actions: [
          if (editing)
            TextButton(
              onPressed: () async {
                if (!confirmDelete) return setState(() => confirmDelete = true);
                await store.remove(widget.item!.id);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(confirmDelete ? 'Emin misin? Sil' : 'Sil', style: TextStyle(color: C.red, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _photoCard(),
            _label('Ne ekliyorsun?'),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1.45,
              children: [
                for (final k in Kind.values)
                  GestureDetector(
                    onTap: () => setState(() => kind = k),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 160),
                      decoration: BoxDecoration(
                        color: kind == k ? C.ink : C.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kind == k ? C.ink : C.line),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(kindIcon(k), color: kind == k ? C.onInk : C.accent, size: 22),
                        SizedBox(height: 6),
                        Text(
                          k == Kind.kart ? 'Kart ödemesi' : k.label,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, color: kind == k ? C.onInk : C.ink),
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
            _label('Başlık'),
            TextField(controller: title, decoration: InputDecoration(hintText: 'Örn. Trafik sigortası')),
            if (sugg.isNotEmpty) ...[
              SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final p in sugg)
                  ActionChip(
                    label: Text(p.title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    backgroundColor: C.card,
                    side: BorderSide(color: C.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                    onPressed: () => setState(() => title.text = p.title),
                  ),
              ]),
            ],
            _label(kind.monthly ? 'Her ay hangi gün?' : 'Son gün'),
            if (kind.monthly)
              DropdownButtonFormField<int>(
                value: day,
                hint: Text('Gün seç'),
                items: [for (var i = 1; i <= 31; i++) DropdownMenuItem(value: i, child: Text('Ayın $i. günü'))],
                onChanged: (v) => setState(() => day = v),
              )
            else
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: Icon(Icons.event_rounded),
                style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, backgroundColor: C.card),
                label: Text(date == null ? 'Tarih seç' : fmtDate(date!)),
              ),
            _label('Not'),
            TextField(
              controller: note,
              decoration: InputDecoration(
                  hintText: switch (kind) {
                Kind.kart => 'Banka ve son 4 hane, örn. Akbank 4821',
                Kind.cek => 'Kime / kimden, çek ya da senet no',
                _ => 'Örn. plaka, ürün, kişi',
              }),
            ),
            _label(kind == Kind.kart ? 'Ekstre tutarı' : 'Tutar'),
            TextField(
              controller: amount,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(hintText: 'İsteğe bağlı', prefixText: '₺ '),
            ),
            SizedBox(height: 14),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Icon(Icons.notifications_rounded, size: 18, color: C.accent),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Hatırlatma: ${kind.reminderText} (${Notifier.timeText}).',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
            if (renewLinkFor(Item(id: '', kind: kind, title: title.text, note: note.text)) case final link?) ...[
              SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(link.url), mode: LaunchMode.externalApplication),
                icon: Icon(Icons.open_in_new_rounded, color: C.accent),
                style: OutlinedButton.styleFrom(backgroundColor: C.card),
                label: Text(link.label),
              ),
            ],
            if (!kIsWeb && (kind.monthly ? day != null : date != null)) ...[
              SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _addCalendar,
                icon: Icon(Icons.event_available_rounded, color: C.accent),
                style: OutlinedButton.styleFrom(backgroundColor: C.card),
                label: Text('Telefonun takvimine de ekle'),
              ),
            ],
            SizedBox(height: 20),
            FilledButton(onPressed: scanning ? null : _save, child: Text('Kaydet')),
          ],
        ),
      ),
    );
  }

  Widget _photoCard() {
    if (kIsWeb && !storeShots) {
      return Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, color: C.accent),
          SizedBox(width: 10),
          Expanded(
            child: Text('Web deneme sürümü. Fotoğraftan otomatik okuma ve bildirimler telefon uygulamasında çalışır.',
                style: TextStyle(fontSize: 12.5)),
          ),
        ]),
      );
    }
    final hasPhoto = photo != null && File(photo!).existsSync();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        if (hasPhoto)
          Image.file(File(photo!), height: 170, width: double.infinity, fit: BoxFit.cover)
        else
          Container(
            height: 120,
            width: double.infinity,
            color: C.card2,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.document_scanner_rounded, size: 36, color: C.accent),
              SizedBox(height: 6),
              Text('Fotoğrafını çek, tarihi biz okuyalım', style: TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
        Padding(
          padding: EdgeInsets.all(12),
          child: scanning
              ? Row(children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Belge okunuyor…'),
                ])
              : Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _takePhoto(ImageSource.camera),
                      icon: Icon(Icons.photo_camera_rounded),
                      label: Text('Fotoğraf çek'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _takePhoto(ImageSource.gallery),
                      icon: Icon(Icons.photo_library_rounded),
                      label: Text('Galeri'),
                    ),
                  ),
                ]),
        ),
      ]),
    );
  }
}
