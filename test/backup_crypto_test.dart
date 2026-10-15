import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_test/flutter_test.dart';

/// Mirrors BackupService's format: IV || AES-256-CBC(checksum || data),
/// key = SHA-256(passphrase). Guards the round-trip and wrong-passphrase
/// behaviour without touching the filesystem.
void main() {
  Uint8List encryptPayload(String passphrase, List<int> plain) {
    final key = enc.Key(Uint8List.fromList(sha256.convert(utf8.encode(passphrase)).bytes));
    final iv = enc.IV.fromSecureRandom(16);
    final payload = [...sha256.convert(plain).bytes, ...plain];
    final cipher = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = cipher.encryptBytes(payload, iv: iv);
    return Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
  }

  List<int>? decryptPayload(String passphrase, List<int> bytes) {
    final key = enc.Key(Uint8List.fromList(sha256.convert(utf8.encode(passphrase)).bytes));
    final iv = enc.IV(Uint8List.fromList(bytes.sublist(0, 16)));
    final cipher = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    try {
      final payload =
          cipher.decryptBytes(enc.Encrypted(Uint8List.fromList(bytes.sublist(16))), iv: iv);
      final checksum = payload.sublist(0, 32);
      final data = payload.sublist(32);
      if (sha256.convert(data).bytes.toString() != checksum.toString()) return null;
      return data;
    } catch (_) {
      return null;
    }
  }

  test('round-trip restores original bytes', () {
    final data = List<int>.generate(1024, (i) => i % 251);
    final sealed = encryptPayload('rahasia-123', data);
    expect(decryptPayload('rahasia-123', sealed), data);
  });

  test('wrong passphrase fails checksum instead of returning garbage', () {
    final data = utf8.encode('sqlite-bytes-here');
    final sealed = encryptPayload('benar', data);
    expect(decryptPayload('salah', sealed), isNull);
  });
}
