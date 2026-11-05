// Türkiye'ye özel otomatik tarihler ve yenileme bağlantıları
import 'models.dart';

/// Araç muayenesi: hususi otomobilde ilk muayene tescilden 3 yıl sonra, sonra 2 yılda bir.
/// Ticari araçta her yıl. (Genel kural; araç türüne göre farklılık olabilir.)
DateTime nextInspection(DateTime firstRegistration, {bool commercial = false, DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final first = commercial ? 1 : 3;
  final step = commercial ? 1 : 2;
  var d = DateTime(firstRegistration.year + first, firstRegistration.month, firstRegistration.day);
  while (d.isBefore(today)) {
    d = DateTime(d.year + step, d.month, d.day);
  }
  return d;
}

/// Bir sonraki ayın-gününe denk gelen tarih (bugün dahil)
DateTime nextYearly(int month, int day, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final d = monthDay(today.year, month, day);
  return d.isBefore(today) ? monthDay(today.year + 1, month, day) : d;
}

/// Motorlu Taşıtlar Vergisi: 1. taksit Ocak sonu, 2. taksit Temmuz sonu
List<Item> mtvItems(String plate, String Function() newId) => [
      Item(id: newId(), kind: Kind.belge, title: 'MTV 1. taksit', note: plate, date: nextYearly(1, 31)),
      Item(id: newId(), kind: Kind.belge, title: 'MTV 2. taksit', note: plate, date: nextYearly(7, 31)),
    ];

/// Emlak vergisi: 1. taksit Mayıs sonu, 2. taksit Kasım sonu
List<Item> propertyTaxItems(String note, String Function() newId) => [
      Item(id: newId(), kind: Kind.belge, title: 'Emlak vergisi 1. taksit', note: note, date: nextYearly(5, 31)),
      Item(id: newId(), kind: Kind.belge, title: 'Emlak vergisi 2. taksit', note: note, date: nextYearly(11, 30)),
    ];

class RenewLink {
  const RenewLink(this.label, this.url);
  final String label;
  final String url;
}

/// Kaydın başlığına göre resmi yenileme / ödeme bağlantısı
RenewLink? renewLinkFor(Item it) {
  final t = trLower('${it.title} ${it.note}');
  if (t.contains('muayene')) return const RenewLink('TÜVTÜRK randevusu al', 'https://www.tuvturk.com.tr');
  if (t.contains('mtv') || t.contains('emlak vergisi')) return const RenewLink('Vergiyi öde (GİB)', 'https://dijital.gib.gov.tr');
  if (t.contains('pasaport') || t.contains('kimlik') || t.contains('ehliyet')) {
    return const RenewLink('Nüfus randevusu al', 'https://randevu.nvi.gov.tr');
  }
  if (t.contains('dask') || t.contains('zorunlu deprem')) return const RenewLink('DASK poliçeni sorgula', 'https://www.dask.gov.tr');
  return null;
}
