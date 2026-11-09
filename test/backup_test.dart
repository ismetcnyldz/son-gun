import 'package:flutter_test/flutter_test.dart';
import 'package:son_gun/backup_crypto.dart';

void main() {
  test('şifreli yedek açılıyor', () async {
    const plain = '{"items":[{"id":"1","title":"Trafik sigortası"}],"photos":{}}';
    final enc = await encryptBackup(plain, 'gizli123');
    expect(isEncryptedBackup(enc), true);
    expect(enc.contains('Trafik'), false);
    expect(await decryptBackup(enc, 'gizli123'), plain);
  });

  test('yanlış şifre reddediliyor', () async {
    final enc = await encryptBackup('merhaba', 'dogru-sifre');
    expect(() => decryptBackup(enc, 'yanlis-sifre'), throwsA(isA<WrongPassword>()));
  });

  test('bozuk dosya tanınıyor', () async {
    expect(() => decryptBackup('VKB2:@@@', 'x'), throwsA(isA<NotABackup>()));
  });

  test('ipucu okunuyor, şifre açık edilmiyor', () async {
    final enc = await encryptBackup('veri', 'gizli123', hint: 'en sevdiğim renk');
    expect(backupHint(enc), 'en sevdiğim renk');
    expect(enc.contains('gizli123'), false);
    expect(await decryptBackup(enc, 'gizli123'), 'veri');
  });
}
