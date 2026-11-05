// Ayarlar: görünüm, kilit, Türkiye takvimi, yedekleme
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:url_launcher/url_launcher.dart';

import 'entitlement.dart';
import 'lock.dart';
import 'main.dart';
import 'models.dart';
import 'paywall.dart';
import 'turkey.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  void _toast(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t), behavior: SnackBarBehavior.floating));

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
        child: Text(t.toUpperCase(), style: GoogleFonts.manrope(fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w800, color: C.muted)),
      );

  Widget _tile({required IconData icon, required String title, String? sub, Widget? trailing, VoidCallback? onTap, Color? color}) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: IconBox(icon: icon, color: color ?? C.accent, size: 40),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: C.ink)),
          subtitle: sub == null ? null : Text(sub, style: TextStyle(color: C.muted, fontSize: 12.5)),
          trailing: trailing ?? (onTap == null ? null : Icon(Icons.chevron_right_rounded, color: C.muted)),
          onTap: onTap,
        ),
      );

  Future<void> _copyBackup() async {
    final text = store.exportBackup();
    await Clipboard.setData(ClipboardData(text: text));
    _toast('${store.items.length} kayıt panoya kopyalandı. Notlara, e-postaya ya da WhatsApp\'ta kendine yapıştırıp sakla.');
  }

  Future<void> _restore() async {
    final ctl = TextEditingController();
    final d = await Clipboard.getData('text/plain');
    if (d?.text?.startsWith('SONGUN1:') ?? false) ctl.text = d!.text!;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.card,
        title: Text('Yedekten geri yükle', style: display(22)),
        content: TextField(
          controller: ctl,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'Kopyaladığın yedeği buraya yapıştır (SONGUN1: ile başlar)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Geri yükle'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final n = await store.importBackup(ctl.text);
      _toast(n == 0 ? 'Yeni kayıt bulunamadı (hepsi zaten var).' : '$n kayıt geri yüklendi.');
    } catch (_) {
      _toast('Yedek okunamadı. Metnin tamamını kopyaladığından emin ol.');
    }
  }

  Future<void> _mail(String subject) async {
    final platform = kIsWeb ? 'Web' : Theme.of(context).platform.name;
    final body = '\n\n---\nUygulama: $appName $appVersion\nPlatform: $platform\nKayıt sayısı: ${store.items.length}';
    final uri = Uri.parse('mailto:$supportEmail?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
    final ok = await launchUrl(uri);
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: supportEmail));
      _toast('E-posta uygulaması açılamadı. Adres kopyalandı: $supportEmail');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = entitlement.subscribed
        ? 'Aboneliğin aktif'
        : entitlement.inTrial
            ? 'Ücretsiz deneme: ${entitlement.trialDaysLeft} gün kaldı'
            : entitlement.trialStarted
                ? 'Deneme bitti, hatırlatmalar durdu'
                : '${Entitlement.trialDays} gün ücretsiz dene';
    return Scaffold(
      appBar: AppBar(title: Text('Ayarlar', style: display(24))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            _label('Abonelik'),
            _tile(
              icon: Icons.workspace_premium_rounded,
              title: 'Son Gün Premium',
              sub: sub,
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallPage()));
                if (mounted) setState(() {});
              },
            ),
            _label('Türkiye takvimi'),
            _tile(
              icon: Icons.auto_awesome_rounded,
              title: 'Tarihleri otomatik ekle',
              sub: 'Araç muayenesi, MTV ve emlak vergisi taksitleri',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TurkeyCalendarPage())),
            ),
            _label('Görünüm'),
            for (final (m, t, i) in [
              (ThemeMode.system, 'Telefonla aynı', Icons.brightness_auto_rounded),
              (ThemeMode.light, 'Açık tema', Icons.light_mode_rounded),
              (ThemeMode.dark, 'Koyu tema', Icons.dark_mode_rounded),
            ])
              _tile(
                icon: i,
                title: t,
                trailing: themeMode.value == m ? Icon(Icons.check_circle_rounded, color: C.accent) : null,
                onTap: () async {
                  await setThemeMode(m);
                  if (mounted) setState(() {});
                },
              ),
            _label('Güvenlik'),
            if (kIsWeb)
              _tile(icon: Icons.lock_rounded, title: 'Uygulama kilidi', sub: 'Telefon uygulamasında kullanılabilir')
            else
              ValueListenableBuilder<bool>(
                valueListenable: lockEnabled,
                builder: (_, on, __) => _tile(
                  icon: Icons.lock_rounded,
                  title: 'Uygulama kilidi',
                  sub: 'Açarken Face ID, parmak izi ya da telefon şifresi',
                  trailing: Switch(
                    value: on,
                    onChanged: (v) async {
                      final err = await setLockEnabled(v);
                      if (err != null) _toast(err);
                    },
                  ),
                ),
              ),
            _label('Yedekleme'),
            _tile(icon: Icons.copy_all_rounded, title: 'Yedeği kopyala', sub: 'Bütün kayıtlar tek metin olarak panoya kopyalanır', onTap: _copyBackup),
            _tile(icon: Icons.restore_rounded, title: 'Yedekten geri yükle', sub: 'Yeni telefonda kopyaladığın yedeği yapıştır', onTap: _restore),
            _label('Destek'),
            _tile(icon: Icons.bug_report_rounded, title: 'Sorun bildir', sub: 'Bir hata mı gördün? Bize yaz, düzeltelim.', onTap: () => _mail('Son Gün - Sorun bildirimi')),
            _tile(icon: Icons.lightbulb_rounded, title: 'Öneri gönder', sub: 'Eklenmesini istediğin bir şey var mı?', onTap: () => _mail('Son Gün - Öneri')),
            _label('Hakkında'),
            _tile(icon: Icons.shield_moon_rounded, title: 'Gizlilik', sub: 'Kayıtların sadece bu cihazda tutulur. Kart numarası, şifre istenmez.'),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(child: Text('$appName · sürüm $appVersion', style: TextStyle(color: C.muted, fontSize: 12))),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Türkiye takvimi
class TurkeyCalendarPage extends StatefulWidget {
  const TurkeyCalendarPage({super.key});
  @override
  State<TurkeyCalendarPage> createState() => _TurkeyCalendarPageState();
}

class _TurkeyCalendarPageState extends State<TurkeyCalendarPage> {
  final plate = TextEditingController();
  final home = TextEditingController();
  DateTime? registration;
  bool commercial = false;
  bool wantInspection = true;
  bool wantMtv = true;
  bool wantProperty = false;
  int _seq = 0;

  String _id() => '${DateTime.now().microsecondsSinceEpoch}${_seq++}';

  @override
  void dispose() {
    plate.dispose();
    home.dispose();
    super.dispose();
  }

  Future<void> _pickReg() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: registration ?? DateTime(now.year - 3, now.month, now.day),
      firstDate: DateTime(1980),
      lastDate: now,
      helpText: 'İlk tescil tarihi (ruhsatta yazar)',
    );
    if (d != null) setState(() => registration = d);
  }

  Future<void> _add() async {
    final p = plate.text.trim().toUpperCase();
    final list = <Item>[];
    if (wantInspection) {
      if (registration == null) {
        _toast('Muayene için ilk tescil tarihini seç.');
        return;
      }
      list.add(Item(id: _id(), kind: Kind.belge, title: 'Araç muayenesi', note: p, date: nextInspection(registration!, commercial: commercial)));
    }
    if (wantMtv) list.addAll(mtvItems(p, _id));
    if (wantProperty) list.addAll(propertyTaxItems(home.text.trim(), _id));
    if (list.isEmpty) {
      _toast('En az bir seçenek işaretle.');
      return;
    }
    final n = await store.addMany(list);
    if (!mounted) return;
    _toast(n == 0 ? 'Bu tarihler zaten ekli.' : '$n tarih eklendi, hatırlatmalar kuruldu.');
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _toast(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t), behavior: SnackBarBehavior.floating));

  Widget _check(String title, String sub, bool v, ValueChanged<bool> on) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: CheckboxListTile(
          value: v,
          onChanged: (x) => on(x ?? false),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: C.ink)),
          subtitle: Text(sub, style: TextStyle(color: C.muted, fontSize: 12.5)),
          activeColor: C.accent,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final preview = wantInspection && registration != null ? nextInspection(registration!, commercial: commercial) : null;
    return Scaffold(
      appBar: AppBar(title: Text('Türkiye takvimi', style: display(24))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Text('Bilmen gereken resmi tarihleri senin yerine hesaplayıp ekleyelim.', style: TextStyle(color: C.muted)),
            const SizedBox(height: 16),
            Text('ARACIN', style: GoogleFonts.manrope(fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w800, color: C.muted)),
            const SizedBox(height: 8),
            TextField(controller: plate, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'Plaka (örn. 34 ABC 123)')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickReg,
              icon: const Icon(Icons.event_rounded),
              style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, backgroundColor: C.card),
              label: Text(registration == null ? 'İlk tescil tarihi (ruhsatta yazar)' : 'İlk tescil: ${fmtDate(registration!)}'),
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              value: commercial,
              onChanged: (v) => setState(() => commercial = v),
              title: Text('Ticari araç (taksi, kamyonet vb.)', style: TextStyle(color: C.ink, fontWeight: FontWeight.w700)),
              activeColor: C.accent,
            ),
            const SizedBox(height: 4),
            _check('Araç muayenesi',
                preview == null ? 'Hususi otomobil: ilk 3 yıl, sonra 2 yılda bir' : 'Sıradaki muayene: ${fmtDate(preview)}', wantInspection, (v) => setState(() => wantInspection = v)),
            _check('MTV taksitleri', 'Ocak sonu ve Temmuz sonu', wantMtv, (v) => setState(() => wantMtv = v)),
            const SizedBox(height: 10),
            Text('EVİN', style: GoogleFonts.manrope(fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w800, color: C.muted)),
            const SizedBox(height: 8),
            _check('Emlak vergisi taksitleri', 'Mayıs sonu ve Kasım sonu (ev sahibiysen)', wantProperty, (v) => setState(() => wantProperty = v)),
            if (wantProperty)
              TextField(controller: home, decoration: const InputDecoration(hintText: 'Not (örn. Kadıköy daire)')),
            const SizedBox(height: 12),
            Text('Tarihler genel kurallara göre hesaplanır. Aracının muayene tarihini TÜVTÜRK\'ten, vergi tarihlerini GİB\'den teyit et.',
                style: TextStyle(color: C.muted, fontSize: 12)),
            const SizedBox(height: 18),
            FilledButton(onPressed: _add, child: const Text('Takvimime ekle')),
          ],
        ),
      ),
    );
  }
}
