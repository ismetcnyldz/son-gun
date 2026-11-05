// Yedek dosyasını şifreleme: PBKDF2 (SHA-256) ile şifreden anahtar, AES-256-GCM ile şifreleme.
// Biçim: "DURT2:" + base64(json{v, it, s, n, m, c})
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

const backupPrefix = 'DURT2:';
const _iterations = 60000;

class WrongPassword implements Exception {}

class NotABackup implements Exception {}

bool isEncryptedBackup(String text) => text.trimLeft().startsWith(backupPrefix);

List<int> _random(int n) {
  final r = Random.secure();
  return List<int>.generate(n, (_) => r.nextInt(256));
}

Future<SecretKey> _key(String password, List<int> salt, int iterations) =>
    Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256)
        .deriveKeyFromPassword(password: password, nonce: salt);

Future<String> encryptBackup(String plain, String password, {String? hint}) async {
  final salt = _random(16);
  final algo = AesGcm.with256bits();
  final key = await _key(password, salt, _iterations);
  final box = await algo.encrypt(utf8.encode(plain), secretKey: key, nonce: algo.newNonce());
  final payload = {
    'v': 2,
    'it': _iterations,
    's': base64Encode(salt),
    'n': base64Encode(box.nonce),
    'm': base64Encode(box.mac.bytes),
    'c': base64Encode(box.cipherText),
    if (hint != null && hint.trim().isNotEmpty) 'h': hint.trim(),
  };
  return backupPrefix + base64Encode(utf8.encode(jsonEncode(payload)));
}

Future<String> decryptBackup(String text, String password) async {
  final Map<String, dynamic> p;
  try {
    p = jsonDecode(utf8.decode(base64Decode(text.trim().substring(backupPrefix.length)))) as Map<String, dynamic>;
  } catch (_) {
    throw NotABackup();
  }
  final key = await _key(password, base64Decode(p['s'] as String), (p['it'] as int?) ?? _iterations);
  try {
    final clear = await AesGcm.with256bits().decrypt(
      SecretBox(base64Decode(p['c'] as String), nonce: base64Decode(p['n'] as String), mac: Mac(base64Decode(p['m'] as String))),
      secretKey: key,
    );
    return utf8.decode(clear);
  } on SecretBoxAuthenticationError {
    throw WrongPassword();
  }
}

/// Şifreli yedekteki ipucu (şifreyi açık etmez). Yoksa null.
String? backupHint(String text) {
  try {
    final p = jsonDecode(utf8.decode(base64Decode(text.trim().substring(backupPrefix.length)))) as Map<String, dynamic>;
    final h = p['h'];
    return h is String && h.isNotEmpty ? h : null;
  } catch (_) {
    return null;
  }
}
