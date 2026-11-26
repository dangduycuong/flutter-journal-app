import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();
  static const _keyToken = 'github_token';
  static const _keyOwner = 'github_owner';
  static const _keyRepo = 'github_repo';
  static const _keyBiometricLock = 'biometric_lock_enabled';
  static const _keyAppPin = 'app_pin_code';
  static const _keyFontScale = 'app_font_scale';

  // Notifier toàn cục cập nhật cỡ chữ ngay lập tức cho toàn app
  static final ValueNotifier<double> fontScaleNotifier = ValueNotifier<double>(
    1.0,
  );

  Future<File> _getMacConfigFile() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/.app_config.json');
  }

  Future<void> initFontScale() async {
    final scale = await getFontScale();
    fontScaleNotifier.value = scale;
  }

  Future<double> getFontScale() async {
    if (Platform.isMacOS) {
      final file = await _getMacConfigFile();
      if (await file.exists()) {
        final map =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        return (map[_keyFontScale] as num?)?.toDouble() ?? 1.0;
      }
      return 1.0;
    }
    final val = await _storage.read(key: _keyFontScale);
    return double.tryParse(val ?? '') ?? 1.0;
  }

  Future<void> setFontScale(double scale) async {
    // Làm tròn 2 chữ số thập phân (bội số của 0.05) và giới hạn từ 85% -> 150%
    final clamped = ((scale * 20).round() / 20).clamp(0.85, 1.50);
    fontScaleNotifier.value = clamped;

    if (Platform.isMacOS) {
      final file = await _getMacConfigFile();
      Map<String, dynamic> map = {};
      if (await file.exists()) {
        map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }
      map[_keyFontScale] = clamped;
      await file.writeAsString(jsonEncode(map));
      return;
    }
    await _storage.write(key: _keyFontScale, value: clamped.toStringAsFixed(2));
  }

  Future<void> saveGitHubConfig({
    required String owner,
    required String token,
    String repo = 'my-journal-data',
  }) async {
    if (Platform.isMacOS) {
      final file = await _getMacConfigFile();
      Map<String, dynamic> map = {};
      if (await file.exists()) {
        map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }
      map[_keyOwner] = owner.trim();
      map[_keyToken] = token.trim();
      map[_keyRepo] = repo.trim();
      await file.writeAsString(jsonEncode(map));
      return;
    }
    await _storage.write(key: _keyOwner, value: owner.trim());
    await _storage.write(key: _keyToken, value: token.trim());
    await _storage.write(key: _keyRepo, value: repo.trim());
  }

  Future<Map<String, String?>> getGitHubConfig() async {
    if (Platform.isMacOS) {
      final file = await _getMacConfigFile();
      if (await file.exists()) {
        final map =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        return {
          'owner': map[_keyOwner] as String?,
          'token': map[_keyToken] as String?,
          'repo': (map[_keyRepo] as String?) ?? 'my-journal-data',
        };
      }
      return {'owner': null, 'token': null, 'repo': 'my-journal-data'};
    }
    return {
      'owner': await _storage.read(key: _keyOwner),
      'token': await _storage.read(key: _keyToken),
      'repo': await _storage.read(key: _keyRepo) ?? 'my-journal-data',
    };
  }

  Future<void> setBiometricLockEnabled(bool enabled) async {
    if (Platform.isMacOS) return;
    await _storage.write(key: _keyBiometricLock, value: enabled.toString());
  }

  Future<bool> isBiometricLockEnabled() async {
    if (Platform.isMacOS) return false;
    final val = await _storage.read(key: _keyBiometricLock);
    return val == 'true';
  }

  Future<void> setAppPin(String? pin) async {
    if (Platform.isMacOS) return;
    if (pin == null || pin.isEmpty) {
      await _storage.delete(key: _keyAppPin);
    } else {
      await _storage.write(key: _keyAppPin, value: pin);
    }
  }

  Future<String?> getAppPin() async {
    if (Platform.isMacOS) return null;
    return await _storage.read(key: _keyAppPin);
  }

  Future<void> clearConfig() async {
    if (Platform.isMacOS) {
      final file = await _getMacConfigFile();
      if (await file.exists()) await file.delete();
      return;
    }
    await _storage.deleteAll();
  }
}
