import 'dart:convert';
import 'package:encrypt/encrypt.dart';

class EncryptionUtil {
  static final EncryptionUtil _instance = EncryptionUtil._internal();
  factory EncryptionUtil() => _instance;
  EncryptionUtil._internal();

  final _key = Key.fromSecureRandom(32);
  final _iv = IV.fromSecureRandom(16);
  late final _encrypter = Encrypter(AES(_key));

  Future<String?> encryptPayload(Map<String, dynamic> payload) async {
    try {
      final jsonString = jsonEncode(payload);
      final encrypted = _encrypter.encrypt(jsonString, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      print('Error encrypting payload: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> decryptPayload(String encryptedPayload) async {
    try {
      final encrypted = Encrypted.fromBase64(encryptedPayload);
      final decrypted = _encrypter.decrypt(encrypted, iv: _iv);
      return jsonDecode(decrypted);
    } catch (e) {
      print('Error decrypting payload: $e');
      return null;
    }
  }
} 