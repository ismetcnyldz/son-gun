// Yedek dosyası: kayıtlar + belge fotoğrafları, şifreyle korunur.
// iCloud Drive, Google Drive, WhatsApp ya da e-postaya kaydedilir; yeni telefonda geri yüklenir.
import 'dart:convert';
import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'backup_crypto.dart';
import 'main.dart' show store;
import 'models.dart';

export 'backup_crypto.dart' show WrongPassword, NotABackup;

String _fileName() {
  final d = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return 'Durt-yedek-${d.year}-${two(d.month)}-${two(d.day)}.durt';
}

/// Kayıtları ve fotoğrafları tek JSON metnine çevirir
Future<String> _buildPlain() async {
  final photos = <String, String>{};
  if (!kIsWeb) {
    for (final it in store.items) {
      final path = it.photo;
      if (path == null) continue;
      try {
        final f = File(path);
        if (await f.exists()) photos[it.id] = base64Encode(await f.readAsBytes());
      } catch (_) {}
    }
  }
  return jsonEncode({
    'app': 'durt',
    'v': 2,
    'created': DateTime.now().toIso8601String(),
    'items': store.items.map((e) => e.toJson()).toList(),
    'photos': photos,
  });
}

/// Şifreli yedek dosyası oluşturup paylaşım ekranını açar. Fotoğraf sayısını döner.
Future<int> shareBackupFile(String password) async {
  final plain = await _buildPlain();
  final text = await encryptBackup(plain, password);
  final bytes = Uint8List.fromList(utf8.encode(text));
  final name = _fileName();
  if (kIsWeb) {
    await Share.shareXFiles([XFile.fromData(bytes, name: name, mimeType: 'application/octet-stream')], fileNameOverrides: [name]);
  } else {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(f.path, mimeType: 'application/octet-stream')], subject: 'Dürt yedeği');
  }
  return (jsonDecode(plain)['photos'] as Map).length;
}

/// Dosya seçtirir ve içeriğini döner. Vazgeçilirse null.
Future<String?> pickBackupFile() async {
  final r = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
  if (r == null || r.files.isEmpty) return null;
  final f = r.files.single;
  var bytes = f.bytes;
  if (bytes == null && !kIsWeb && f.path != null) bytes = await File(f.path!).readAsBytes();
  if (bytes == null) throw NotABackup();
  try {
    return utf8.decode(bytes);
  } catch (_) {
    throw NotABackup();
  }
}

/// Seçilen yedeği geri yükler. Şifreli yedekte [password] gerekir. Eklenen kayıt sayısını döner.
Future<int> restoreBackup(String text, {String? password}) async {
  var t = text.trim();
  if (isEncryptedBackup(t)) {
    t = await decryptBackup(t, password ?? '');
  } else if (t.startsWith('SONGUN1:')) {
    return store.importBackup(t); // eski, şifresiz yedek
  }
  final Map<String, dynamic> data;
  try {
    data = jsonDecode(t) as Map<String, dynamic>;
  } catch (_) {
    throw NotABackup();
  }
  if (data['items'] is! List) throw NotABackup();
  final items = (data['items'] as List).map((e) => Item.fromJson(e as Map<String, dynamic>)).toList();
  final photos = (data['photos'] as Map?)?.cast<String, dynamic>() ?? {};
  if (!kIsWeb && photos.isNotEmpty) {
    final dir = await getApplicationDocumentsDirectory();
    for (final it in items) {
      final b64 = photos[it.id];
      if (b64 is! String) {
        it.photo = null;
        continue;
      }
      final path = '${dir.path}/belge_geri_${it.id}.jpg';
      try {
        await File(path).writeAsBytes(base64Decode(b64), flush: true);
        it.photo = path;
      } catch (_) {
        it.photo = null;
      }
    }
  } else {
    for (final it in items) {
      it.photo = null;
    }
  }
  return store.addMany(items);
}
