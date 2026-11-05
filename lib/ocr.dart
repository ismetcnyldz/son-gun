// Fotoğraftan yazı okuma (telefonda, internetsiz) ve belgeden bilgi çıkarma
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'models.dart';

class ScanResult {
  String? title;
  Kind? kind;
  DateTime? date;
  int? day;
  double? amount;
  String raw = '';
}

Future<ScanResult> scanImage(String path) async {
  final rec = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final res = await rec.processImage(InputImage.fromFilePath(path));
    return parseText(res.text);
  } finally {
    await rec.close();
  }
}

final _monthNames = {
  'ocak': 1, 'şubat': 2, 'subat': 2, 'mart': 3, 'nisan': 4, 'mayıs': 5, 'mayis': 5, 'haziran': 6,
  'temmuz': 7, 'ağustos': 8, 'agustos': 8, 'eylül': 9, 'eylul': 9, 'ekim': 10, 'kasım': 11,
  'kasim': 11, 'aralık': 12, 'aralik': 12,
};

const _dueWords = [
  'bitiş', 'bitis', 'geçerlilik', 'gecerlilik', 'son ödeme', 'son odeme', 'vade', 'son kullanma',
  'geçerli', 'gecerli', 'sona er', 'expiry', 'valid', 'garanti süresi', 'muayene geçerlilik',
];

DateTime? _mk(int d, int m, int y) {
  if (y < 100) y += 2000;
  if (m < 1 || m > 12 || d < 1 || d > 31 || y < 2000 || y > 2100) return null;
  final dt = DateTime(y, m, d);
  return dt.month == m ? dt : null;
}

List<DateTime> _datesIn(String line) {
  final out = <DateTime>[];
  for (final m in RegExp(r'(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})').allMatches(line)) {
    final d = _mk(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    if (d != null) out.add(d);
  }
  final low = trLower(line);
  for (final m in RegExp(r'(\d{1,2})\s+([a-zçğıöşü]+)\s+(\d{4})').allMatches(low)) {
    final mon = _monthNames[m[2]!];
    if (mon == null) continue;
    final d = _mk(int.parse(m[1]!), mon, int.parse(m[3]!));
    if (d != null) out.add(d);
  }
  return out;
}

double? _money(String s) {
  final m = RegExp(r'(\d{1,3}(?:\.\d{3})*|\d+),(\d{2})').firstMatch(s);
  if (m == null) return null;
  return double.tryParse('${m[1]!.replaceAll('.', '')}.${m[2]}');
}

ScanResult parseText(String text) {
  final r = ScanResult()..raw = text;
  final low = trLower(text);

  // Tür tahmini
  if (low.contains('zorunlu mali') || low.contains('trafik sigorta')) {
    r..title = 'Trafik sigortası'..kind = Kind.belge;
  } else if (low.contains('kasko')) {
    r..title = 'Kasko'..kind = Kind.belge;
  } else if (low.contains('dask') || low.contains('zorunlu deprem')) {
    r..title = 'DASK (zorunlu deprem sigortası)'..kind = Kind.belge;
  } else if (low.contains('muayene') || low.contains('tüvtürk') || low.contains('tuvturk')) {
    r..title = 'Araç muayenesi'..kind = Kind.belge;
  } else if (low.contains('pasaport') || low.contains('passport')) {
    r..title = 'Pasaport'..kind = Kind.belge;
  } else if (low.contains('sürücü belgesi') || low.contains('surucu belgesi') || low.contains('ehliyet')) {
    r..title = 'Ehliyet'..kind = Kind.belge;
  } else if (low.contains('konut sigorta')) {
    r..title = 'Konut sigortası'..kind = Kind.belge;
  } else if (low.contains('son ödeme') || low.contains('son odeme') || low.contains('hesap özeti') || low.contains('ekstre')) {
    r..title = 'Kredi kartı'..kind = Kind.kart;
  } else if (low.contains('garanti')) {
    r..title = 'Garanti belgesi'..kind = Kind.garanti;
  } else if (low.contains('poliçe') || low.contains('police')) {
    r..title = 'Sigorta poliçesi'..kind = Kind.belge;
  }

  // Tarih: önce "bitiş / son ödeme / geçerlilik" geçen satır ve sonraki satır
  final lines = text.split('\n');
  DateTime? best;
  for (var i = 0; i < lines.length && best == null; i++) {
    final l = trLower(lines[i]);
    if (_dueWords.any(l.contains)) {
      final ds = [..._datesIn(lines[i]), if (i + 1 < lines.length) ..._datesIn(lines[i + 1])];
      if (ds.isNotEmpty) {
        ds.sort();
        best = ds.last;
      }
      if (r.kind == Kind.kart && r.amount == null) r.amount = _money(lines[i]);
    }
  }
  if (best == null) {
    final all = <DateTime>[for (final l in lines) ..._datesIn(l)]..sort();
    if (all.isNotEmpty) {
      final today = dateOnly(DateTime.now());
      final future = all.where((d) => !d.isBefore(today)).toList();
      best = future.isNotEmpty ? future.last : all.last;
    }
  }
  r.date = best;

  // Kart ekstresi: tutar (dönem borcu / ödenecek)
  if (r.kind == Kind.kart) {
    for (final l in lines) {
      final ll = trLower(l);
      if (ll.contains('dönem borcu') || ll.contains('donem borcu') || ll.contains('ödenecek') || ll.contains('toplam borç')) {
        r.amount ??= _money(l);
      }
    }
    if (r.date != null) r.day = r.date!.day;
  }
  return r;
}
