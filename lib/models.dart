// Kayıt modeli ve tarih yardımcıları
import 'dart:convert';

/// Uygulamanın görünen adı. İsim değişirse sadece burası ve AndroidManifest değişir.
const String appName = 'Son Gün';

enum Kind { belge, garanti, kart, abonelik, diger }

extension KindText on Kind {
  String get label => switch (this) {
        Kind.belge => 'Belge',
        Kind.garanti => 'Garanti',
        Kind.kart => 'Kart son ödeme',
        Kind.abonelik => 'Abonelik',
        Kind.diger => 'Diğer',
      };

  String get short => switch (this) {
        Kind.belge => 'BLG',
        Kind.garanti => 'GAR',
        Kind.kart => 'KART',
        Kind.abonelik => 'ABO',
        Kind.diger => 'DİĞ',
      };

  /// Her ay tekrarlayan türler (ayın belli günü)
  bool get monthly => this == Kind.kart || this == Kind.abonelik;
}

class Item {
  Item({
    required this.id,
    required this.kind,
    required this.title,
    this.note = '',
    this.date,
    this.day,
    this.amount,
    this.photo,
  });

  final String id;
  Kind kind;
  String title;
  String note;
  DateTime? date; // tek seferlik son gün
  int? day; // her ay tekrarlayanlar için ayın günü (1-31)
  double? amount;
  String? photo;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'note': note,
        'date': date?.toIso8601String(),
        'day': day,
        'amount': amount,
        'photo': photo,
      };

  static Item fromJson(Map<String, dynamic> j) => Item(
        id: j['id'] as String,
        kind: Kind.values.firstWhere((k) => k.name == j['kind'], orElse: () => Kind.diger),
        title: (j['title'] ?? '') as String,
        note: (j['note'] ?? '') as String,
        date: j['date'] == null ? null : DateTime.tryParse(j['date'] as String),
        day: j['day'] as int?,
        amount: (j['amount'] as num?)?.toDouble(),
        photo: j['photo'] as String?,
      );

  static String encodeList(List<Item> items) => jsonEncode(items.map((e) => e.toJson()).toList());
  static List<Item> decodeList(String s) =>
      (jsonDecode(s) as List).map((e) => Item.fromJson(e as Map<String, dynamic>)).toList();

  /// Bir sonraki son gün (bugün dahil). Tarihi yoksa null.
  DateTime? nextDue([DateTime? now]) {
    final t = dateOnly(now ?? DateTime.now());
    if (kind.monthly && day != null) {
      var c = monthDay(t.year, t.month, day!);
      if (c.isBefore(t)) {
        final n = DateTime(t.year, t.month + 1, 1);
        c = monthDay(n.year, n.month, day!);
      }
      return c;
    }
    return date == null ? null : dateOnly(date!);
  }

  int? daysLeft([DateTime? now]) {
    final d = nextDue(now);
    if (d == null) return null;
    return d.difference(dateOnly(now ?? DateTime.now())).inDays;
  }
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Ayın verilen günü; ay kısa ise son güne çeker (31 -> 30/28).
DateTime monthDay(int y, int m, int day) {
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, day > last ? last : day);
}

const trMonths = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
];

String fmtDate(DateTime d) => '${d.day} ${trMonths[d.month - 1]} ${d.year}';

String fmtMoney(double v) {
  final neg = v < 0;
  final s = v.abs().toStringAsFixed(2);
  final parts = s.split('.');
  final int_ = parts[0];
  final b = StringBuffer();
  for (var i = 0; i < int_.length; i++) {
    if (i > 0 && (int_.length - i) % 3 == 0) b.write('.');
    b.write(int_[i]);
  }
  final dec = parts[1] == '00' ? '' : ',${parts[1]}';
  return '${neg ? '-' : ''}₺$b$dec';
}

/// Türkçe doğru küçük harf (İ -> i, I -> ı)
String trLower(String s) => s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

/// Hazır belge şablonları (Türkiye'ye özel)
class Preset {
  const Preset(this.title, this.kind, [this.hint = '']);
  final String title;
  final Kind kind;
  final String hint;
}

const presets = <Preset>[
  Preset('Trafik sigortası', Kind.belge, 'Plaka'),
  Preset('Kasko', Kind.belge, 'Plaka'),
  Preset('Araç muayenesi', Kind.belge, 'Plaka'),
  Preset('MTV taksidi', Kind.belge, 'Ocak ve Temmuz sonu'),
  Preset('DASK (zorunlu deprem sigortası)', Kind.belge, 'Adres'),
  Preset('Konut sigortası', Kind.belge),
  Preset('Sağlık sigortası', Kind.belge),
  Preset('Ehliyet', Kind.belge, 'Sağlık raporu yenileme'),
  Preset('Pasaport', Kind.belge, 'Kimin pasaportu'),
  Preset('Kimlik kartı', Kind.belge),
  Preset('Kira sözleşmesi', Kind.belge),
  Preset('Telefon garantisi', Kind.garanti, 'Marka, IMEI'),
  Preset('Beyaz eşya garantisi', Kind.garanti, 'Ürün'),
  Preset('Bilgisayar garantisi', Kind.garanti),
  Preset('Kredi kartı', Kind.kart, 'Banka, son 4 hane'),
  Preset('Netflix', Kind.abonelik),
  Preset('Spotify', Kind.abonelik),
  Preset('YouTube Premium', Kind.abonelik),
  Preset('Telefon faturası', Kind.abonelik),
  Preset('Ev interneti', Kind.abonelik),
  Preset('Spor salonu', Kind.abonelik),
  Preset('Kira', Kind.abonelik),
  Preset('Aidat', Kind.abonelik),
];
