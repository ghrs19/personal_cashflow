import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/app_database.dart';

/// Encrypted backup — the fix for the reference app's biggest weakness
/// (it uploaded a *plain* SQLite file to Drive).
///
/// Format: bytes = IV(16) || AES-256-CBC( SHA-256 checksum(32) || db )
/// Key: SHA-256 of the user's passphrase. The embedded checksum lets us
/// distinguish "wrong passphrase" from silent corruption.
class BackupService {
  static const extension = 'pcf';

  static enc.Key _keyFrom(String passphrase) =>
      enc.Key(Uint8List.fromList(sha256.convert(utf8.encode(passphrase)).bytes));

  static Future<File> exportEncrypted(String passphrase) async {
    final dbFile = File(await AppDatabase.dbPath());
    // Flush pending writes by closing and reopening is heavy; the file on
    // disk is consistent because sqflite commits synchronously per call.
    final plain = await dbFile.readAsBytes();
    final checksum = sha256.convert(plain).bytes;
    final payload = Uint8List.fromList([...checksum, ...plain]);

    final iv = enc.IV.fromSecureRandom(16);
    final cipher = enc.Encrypter(enc.AES(_keyFrom(passphrase), mode: enc.AESMode.cbc));
    final encrypted = cipher.encryptBytes(payload, iv: iv);

    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-')
        .substring(0, 19);
    final out = File(p.join(dir.path, 'personal_cashflow_backup_$stamp.$extension'));
    await out.writeAsBytes([...iv.bytes, ...encrypted.bytes]);
    return out;
  }

  static Future<void> restoreEncrypted(File file, String passphrase) async {
    final bytes = await file.readAsBytes();
    if (bytes.length < 17) throw const BackupException('invalid');
    final iv = enc.IV(Uint8List.fromList(bytes.sublist(0, 16)));
    final cipherBytes = bytes.sublist(16);
    final cipher = enc.Encrypter(enc.AES(_keyFrom(passphrase), mode: enc.AESMode.cbc));
    List<int> payload;
    try {
      payload = cipher.decryptBytes(enc.Encrypted(Uint8List.fromList(cipherBytes)), iv: iv);
    } catch (_) {
      throw const BackupException('decrypt');
    }
    if (payload.length < 33) throw const BackupException('invalid');
    final checksum = payload.sublist(0, 32);
    final dbBytes = payload.sublist(32);
    final actual = sha256.convert(dbBytes).bytes;
    if (!_constantTimeEquals(checksum, actual)) {
      throw const BackupException('checksum');
    }
    await AppDatabase.close();
    final target = File(await AppDatabase.dbPath());
    await target.writeAsBytes(dbBytes, flush: true);
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Plain JSON export of every table, for portability/interop.
  static Future<File> exportJson(Future<Map<String, Object?>> Function() dump) async {
    final data = await dump();
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final out = File(p.join(dir.path, 'personal_cashflow_export_$stamp.json'));
    await out.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return out;
  }

  static String randomPassphraseHint() {
    // Not a generator — just guards against accidental empty passphrases.
    return Random().nextInt(900000).toString();
  }
}

class BackupException implements Exception {
  final String code;
  const BackupException(this.code);
  @override
  String toString() => 'BackupException($code)';
}
