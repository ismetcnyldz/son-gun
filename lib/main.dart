import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';
import 'notify.dart';
import 'ocr.dart';
import 'sms.dart';
import 'store.dart';

final store = Store();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Notifier.init();
  } catch (_) {/* bildirim izni yoksa uygulama yine açılsın */}
  await store.load();
  runApp(const SonGunApp());
}

const _seed = Color(0xFF2F5D62);
const _red = Color(0xFFC2412D);
const _amber = Color(0xFFC98A12);
const _green = Color(0xFF3C7D4F);

class SonGunApp extends StatelessWidget {
  const SonGunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        scaffoldBackgroundColor: const Color(0xFFF3F1EC),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [const HomePage(), const PaymentsPage(), const SmsPage()];
    return Scaffold(
      appBar: AppBar(
        title: const Text(appName, style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(child: pages[tab]),
      floatingActionButton: tab == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: () => openEditor(context),
              icon: const Icon(Icons.add),
              label: const Text('Ekle'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'Yaklaşanlar'),
          NavigationDestination(icon: Icon(Icons.credit_card_outlined), selectedIcon: Icon(Icons.credit_card), label: 'Ödemeler'),
          NavigationDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield), label: 'SMS Kontrol'),
        ],
      ),
    );
  }
}

Future<void> openEditor(BuildContext context, [Item? item]) async {
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorPage(item: item)));
}

Color urgency(int? days) {
  if (days == null) return Colors.grey;
  if (days <= 7) return _red;
  if (days <= 30) return _amber;
  return _green;
}

// ---------------- Yaklaşanlar ----------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Kind? filter;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final all = store.upcoming();
        final list = filter == null ? all : all.where((e) => e.kind == filter).toList();
        final soon = all.where((e) => (e.daysLeft() ?? 999) <= 30).length;
        final cs = Theme.of(context).colorScheme;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            Card(
              color: cs.primary,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  Text('$soon', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: cs.onPrimary)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      soon == 0 ? 'Önümüzdeki 30 günde süresi dolan kayıt yok' : 'kaydın süresi 30 gün içinde doluyor',
                      style: TextStyle(color: cs.onPrimary, fontSize: 15),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _chip('Hepsi', filter == null, () => setState(() => filter = null)),
                for (final k in Kind.values) _chip(k.label, filter == k, () => setState(() => filter = k)),
              ]),
            ),
            const SizedBox(height: 8),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(children: [
                  Icon(Icons.inbox_outlined, size: 48, color: cs.outline),
                  const SizedBox(height: 12),
                  const Text('Henüz kayıt yok.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('"Ekle"ye bas, belgenin fotoğrafını çek;\ntarihi uygulama kendisi okusun.', textAlign: TextAlign.center),
                ]),
              ),
            for (final it in list) ItemTile(item: it),
          ],
        );
      },
    );
  }

  Widget _chip(String t, bool sel, VoidCallback on) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(label: Text(t), selected: sel, onSelected: (_) => on()),
      );
}

class ItemTile extends StatelessWidget {
  const ItemTile({super.key, required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final d = item.daysLeft();
    final due = item.nextDue();
    final c = urgency(d);
    final sub = [
      if (item.note.isNotEmpty) item.note,
      if (item.kind.monthly && item.day != null) 'Her ayın ${item.day}. günü',
      if (due != null) fmtDate(due),
      if (item.amount != null) fmtMoney(item.amount!),
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: d != null && d <= 30 ? c : Colors.transparent, width: 1.2),
      ),
      child: ListTile(
        onTap: () => openEditor(context, item),
        leading: CircleAvatar(
          backgroundColor: c.withValues(alpha: 0.14),
          child: Text(item.kind.short, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c)),
        ),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(sub),
        trailing: d == null
            ? null
            : Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(d < 0 ? '${-d}' : '$d', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c)),
                Text(d < 0 ? 'gün geçti' : (d == 0 ? 'bugün!' : 'gün kaldı'), style: const TextStyle(fontSize: 11)),
              ]),
      ),
    );
  }
}

// ---------------- Ödemeler ----------------
class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final cards = store.upcoming().where((e) => e.kind == Kind.kart).toList();
        final subs = store.upcoming().where((e) => e.kind == Kind.abonelik).toList();
        final total = store.monthlyTotal();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            Row(children: [
              Expanded(child: _sum(context, fmtMoney(total), 'Aylık abonelik')),
              const SizedBox(width: 8),
              Expanded(child: _sum(context, fmtMoney(total * 12), 'Yıllık toplam')),
            ]),
            const SizedBox(height: 14),
            Text('Kartlar', style: Theme.of(context).textTheme.titleLarge),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Kart numarası, CVV veya şifre asla istenmez. Sadece banka adı ve son ödeme günü tutulur.',
                  style: TextStyle(fontSize: 13)),
            ),
            if (cards.isEmpty) const Text('Kart eklenmedi.'),
            for (final c in cards) ItemTile(item: c),
            const SizedBox(height: 14),
            Text('Abonelikler', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            if (subs.isEmpty) const Text('Abonelik eklenmedi.'),
            for (final s in subs) ItemTile(item: s),
          ],
        );
      },
    );
  }

  Widget _sum(BuildContext context, String v, String l) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(l, style: const TextStyle(fontSize: 12)),
          ]),
        ),
      );
}

// ---------------- SMS Kontrol ----------------
class SmsPage extends StatefulWidget {
  const SmsPage({super.key});
  @override
  State<SmsPage> createState() => _SmsPageState();
}

class _SmsPageState extends State<SmsPage> {
  final ctl = TextEditingController();
  SmsVerdict? v;

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Bu SMS sahte mi?', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text('Şüphelendiğin mesajı buraya yapıştır. İçindeki linke tıklamadan kontrol edelim.'),
        const SizedBox(height: 12),
        TextField(
          controller: ctl,
          minLines: 4,
          maxLines: 8,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: 'Mesajı buraya yapıştır',
            suffixIcon: IconButton(
              tooltip: 'Yapıştır',
              icon: const Icon(Icons.content_paste),
              onPressed: () async {
                final d = await Clipboard.getData('text/plain');
                if (d?.text != null) setState(() => ctl.text = d!.text!);
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () {
            if (ctl.text.trim().isEmpty) return;
            FocusScope.of(context).unfocus();
            setState(() => v = checkSms(ctl.text));
          },
          icon: const Icon(Icons.search),
          label: const Text('Kontrol et'),
        ),
        const SizedBox(height: 14),
        if (v != null) _result(v!),
      ],
    );
  }

  Widget _result(SmsVerdict v) {
    final c = v.risky ? _red : _green;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        border: Border.all(color: c),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v.risky ? 'Büyük ihtimalle dolandırıcılık' : (v.reasons.isEmpty ? 'Şüpheli bir işaret bulunmadı' : 'Dikkatli ol'),
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: c)),
        const SizedBox(height: 8),
        for (final r in v.reasons) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $r')),
        const SizedBox(height: 6),
        Text(
          v.risky
              ? 'Linke tıklama, ödeme yapma, kod paylaşma. Borcun olup olmadığını e-Devlet\'ten kendin kontrol et.'
              : 'Yine de emin değilsen linke tıklamak yerine kurumun kendi uygulamasından kontrol et.',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }
}

// ---------------- Ekle / Düzenle ----------------
class EditorPage extends StatefulWidget {
  const EditorPage({super.key, this.item});
  final Item? item;
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
    kind = it?.kind ?? Kind.belge;
    title.text = it?.title ?? '';
    note.text = it?.note ?? '';
    amount.text = it?.amount == null ? '' : it!.amount!.toStringAsFixed(2).replaceAll('.', ',');
    date = it?.date;
    day = it?.day;
    photo = it?.photo;
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(found
            ? 'Okundu: ${r.title ?? 'belge'}${r.date != null ? ' · ${fmtDate(r.date!)}' : ''}. Kontrol edip kaydet.'
            : 'Tarih okunamadı. Tarihi elle seçebilirsin.'),
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotoğraf okunamadı. Bilgileri elle girebilirsin.')));
      }
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: date ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 15),
      helpText: 'Son günü seç',
    );
    if (d != null) setState(() => date = d);
  }

  Future<void> _save() async {
    if (title.text.trim().isEmpty) {
      _toast('Bir başlık yaz (örneğin "Trafik sigortası").');
      return;
    }
    if (kind.monthly && day == null) {
      _toast('Ayın hangi günü olduğunu seç.');
      return;
    }
    if (!kind.monthly && date == null) {
      _toast('Son günü seç.');
      return;
    }
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

  void _toast(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    final sugg = presets.where((p) => p.kind == kind).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Kaydı düzenle' : 'Yeni kayıt'),
        actions: [
          if (editing)
            TextButton(
              onPressed: () async {
                if (!confirmDelete) {
                  setState(() => confirmDelete = true);
                  return;
                }
                await store.remove(widget.item!.id);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(confirmDelete ? 'Emin misin? Sil' : 'Sil', style: const TextStyle(color: _red)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Fotoğraf (web deneme sürümünde yok)
          if (kIsWeb)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Bu web deneme sürümü. Fotoğraftan otomatik okuma ve hatırlatma bildirimleri telefon uygulamasında çalışır; burada bilgileri elle girebilirsin.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            )
          else ...[
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              if (!kIsWeb && photo != null && File(photo!).existsSync())
                Image.file(File(photo!), height: 180, width: double.infinity, fit: BoxFit.cover),
              Padding(
                padding: const EdgeInsets.all(12),
                child: scanning
                    ? const Row(children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 12), Text('Belge okunuyor…')])
                    : Row(children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _takePhoto(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera),
                            label: const Text('Fotoğraf çek'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _takePhoto(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Galeriden'),
                          ),
                        ),
                      ]),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          const Text('Poliçe, ekstre, fatura ya da garanti belgesinin fotoğrafını çek; tarih otomatik okunur.', style: TextStyle(fontSize: 13)),
          ],
          const SizedBox(height: 16),
          Text('Tür', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final k in Kind.values)
              ChoiceChip(label: Text(k.label), selected: kind == k, onSelected: (_) => setState(() => kind = k)),
          ]),
          const SizedBox(height: 16),
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Başlık', border: OutlineInputBorder())),
          if (sugg.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final p in sugg)
                ActionChip(
                  label: Text(p.title),
                  onPressed: () => setState(() => title.text = p.title),
                ),
            ]),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: note,
            decoration: InputDecoration(
              labelText: 'Not (isteğe bağlı)',
              hintText: kind == Kind.kart ? 'Banka ve son 4 hane, örn. Akbank 4821' : 'Örn. plaka, ürün, kişi',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (kind.monthly)
            DropdownButtonFormField<int>(
              value: day,
              decoration: InputDecoration(
                labelText: kind == Kind.kart ? 'Son ödeme günü (her ay)' : 'Ödeme günü (her ay)',
                border: const OutlineInputBorder(),
              ),
              items: [for (var i = 1; i <= 31; i++) DropdownMenuItem(value: i, child: Text('Ayın $i. günü'))],
              onChanged: (v) => setState(() => day = v),
            )
          else
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), alignment: Alignment.centerLeft),
              label: Text(date == null ? 'Son günü seç' : 'Son gün: ${fmtDate(date!)}'),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: kind == Kind.kart ? 'Ekstre tutarı (isteğe bağlı)' : 'Tutar (isteğe bağlı)',
              prefixText: '₺ ',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            kind.monthly ? 'Hatırlatma: 3 gün ve 1 gün kala, son gün sabahı.' : 'Hatırlatma: 30, 7 ve 1 gün kala, son gün sabahı.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: scanning ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Kaydet', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
