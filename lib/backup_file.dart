// Yedeği dosya olarak paylaş (iCloud Drive, Google Drive, WhatsApp, e-posta) ve dosyadan geri yükle
import 'dart:convert';
import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'main.dart' show store;

String _fileName() {
  final d = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return 'SonGun-yedek-${d.year}-${two(d.month)}-${two(d.day)}.songun';
}

Future<void> shareBackupFile() async {
  final bytes = Uint8List.fromList(utf8.encode(store.exportBackup()));
  final name = _fileName();
  if (kIsWeb) {
    await Share.shareXFiles([XFile.fromData(bytes, name: name, mimeType: 'text/plain')], fileNameOverrides: [name]);
    return;
  }
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$name');
  await f.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([XFile(f.path, mimeType: 'text/plain')], subject: 'Son Gün yedeği');
}

/// Dosya seçtirir; eklenen kayıt sayısını döner. Vazgeçilirse null.
Future<int?> importBackupFile() async {
  final r = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
  if (r == null || r.files.isEmpty) return null;
  final f = r.files.single;
  var bytes = f.bytes;
  if (bytes == null && !kIsWeb && f.path != null) bytes = await File(f.path!).readAsBytes();
  if (bytes == null) throw 'Dosya okunamadı';
  return store.importBackup(utf8.decode(bytes));
}
