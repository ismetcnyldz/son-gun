import 'package:flutter_test/flutter_test.dart';
import 'package:son_gun/models.dart';
import 'package:son_gun/ocr.dart';
import 'package:son_gun/sms.dart';

void main() {
  test('trafik sigortası poliçesinden bitiş tarihi okunur', () {
    final r = parseText('ZORUNLU MALİ SORUMLULUK SİGORTASI\nBaşlangıç: 14.12.2025\nBitiş Tarihi: 14.12.2026\nPlaka 34 ABC 123');
    expect(r.title, 'Trafik sigortası');
    expect(r.date, DateTime(2026, 12, 14));
  });

  test('kart ekstresinden son ödeme ve tutar okunur', () {
    final r = parseText('HESAP ÖZETİ\nSon Ödeme Tarihi 08/11/2026\nDönem Borcu 8.460,25 TL');
    expect(r.kind, Kind.kart);
    expect(r.day, 8);
    expect(r.amount, 8460.25);
  });

  test('ay adıyla yazılmış tarih', () {
    final r = parseText('Garanti Belgesi\nGaranti süresi bitiş: 3 Şubat 2028');
    expect(r.kind, Kind.garanti);
    expect(r.date, DateTime(2028, 2, 3));
  });

  test('sahte icra SMS yakalanır', () {
    final v = checkSms('Sayin vatandas hakkinizda icra takibi baslatilmistir. 24 saat icinde odeme yapiniz: http://e-devlet-icra-odeme.com/dosya');
    expect(v.risky, isTrue);
  });

  test('gerçek kargo SMS temiz', () {
    final v = checkSms('Gonderiniz yola cikti. Takip no 7290045812. Detay: https://www.yurticikargo.com');
    expect(v.risky, isFalse);
  });

  test('kart son ödeme günü kısa ayda son güne çekilir', () {
    final it = Item(id: '1', kind: Kind.kart, title: 'Kart', day: 31);
    expect(it.nextDue(DateTime(2027, 2, 10)), DateTime(2027, 2, 28));
  });
}
