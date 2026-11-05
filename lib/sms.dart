// Dolandırıcılık SMS kontrolü (kural tabanlı, internetsiz)
import 'models.dart';

class SmsVerdict {
  SmsVerdict(this.risky, this.reasons);
  final bool risky;
  final List<String> reasons;
}

const _trustedHosts = [
  'turkiye.gov.tr', 'gov.tr', 'ptt.gov.tr', 'yurticikargo.com', 'araskargo.com.tr', 'mngkargo.com.tr',
  'suratkargo.com.tr', 'trendyol.com', 'hepsiburada.com', 'hepsijet.com', 'getir.com',
];

SmsVerdict checkSms(String text) {
  final t = trLower(text);
  final reasons = <String>[];
  final links = RegExp(r'(https?://)?([a-z0-9-]+\.)+[a-z]{2,}(/\S*)?').allMatches(t).map((m) => m[0]!).toList();
  for (final l in links) {
    final host = l.replaceFirst(RegExp(r'^https?://'), '').split('/').first;
    final trusted = _trustedHosts.any((h) => host == h || host.endsWith('.$h'));
    if (!trusted) {
      reasons.add('Link resmi ya da bilinen bir adrese gitmiyor: $host. Devlet kurumlarının adresi .gov.tr ile biter.');
      if (RegExp(r'e-?devlet|turkiye|icra|ptt|hgs|vergi|gib').hasMatch(host)) {
        reasons.add('Adres, resmi bir kurumun adını taklit ediyor gibi görünüyor.');
      }
      break;
    }
  }
  if (RegExp(r'icra|dava|mahkeme|haciz|borcunuz|borç|borc|hgs|ceza|vergi').hasMatch(t)) {
    reasons.add('İcra, dava, HGS veya vergi borcu gibi korkutucu bir konu kullanılıyor. Resmi kurumlar SMS ile ödeme linki göndermez.');
  }
  if (RegExp(r'24 saat|hemen|acil|son gün|bugün içinde|aksi halde|engellen').hasMatch(t)) {
    reasons.add('Acele ettirmeye çalışıyor.');
  }
  if (RegExp(r'ödeme|odeme|kart bilgi|şifre|sifre|doğrulama kodu|dogrulama kodu|iade').hasMatch(t)) {
    reasons.add('Ödeme, kart bilgisi, şifre ya da kod istiyor.');
  }
  if (RegExp(r'kazandınız|kazandiniz|hediye|ödül|odul|çekiliş|cekilis').hasMatch(t)) {
    reasons.add('Ödül veya hediye vaadi var.');
  }
  return SmsVerdict(reasons.length >= 2, reasons);
}
