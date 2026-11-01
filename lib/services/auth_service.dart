
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:crypto/crypto.dart';

class AuthService {
  static const _boxName = 'authBox';
  static const _sessionKey = '__current_user';

  static Future<void> init() async {
    await Hive.openBox<String>(_boxName);
  }

  static String? currentUser() {
    final box = Hive.box<String>(_boxName);
    return box.get(_sessionKey);
  }

  static Future<void> signUp(String login, String password) async {
    final box = Hive.box<String>(_boxName);
    if (box.containsKey(login)) {
      throw Exception('Пользователь $login уже зарегистрирован');
    }
    final hash = sha256.convert(utf8.encode(password)).toString();
    await box.put(login, hash);
  }

  static Future<void> signIn(String login, String password) async {
    final box = Hive.box<String>(_boxName);
    final storedHash = box.get(login);
    if (storedHash == null) {
      throw Exception('Пользователь не найден');
    }
    final inputHash = sha256.convert(utf8.encode(password)).toString();
    if (inputHash != storedHash) {
      throw Exception('Неверный пароль');
    }
    await box.put(_sessionKey, login);
  }

  static Future<void> signOut() async {
    final box = Hive.box<String>(_boxName);
    await box.delete(_sessionKey);
  }
}
