import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();
  static const _keyToken = 'github_token';
  static const _keyOwner = 'github_owner';
  static const _keyRepo = 'github_repo';
  static const _keyBiometricLock = 'biometric_lock_enabled';

  Future<File> _getMacConfigFile() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/.app_config.json');
  }

  Future<void> saveGitHubConfig({
    required String owner,
    required String token,
    String repo = 'my-journal-data',
  }) async {
    if (Platform.isMacOS) {
      final file = await _getMacConfigFile();
      await file.writeAsString(
        jsonEncode({
          _keyOwner: owner.trim(),
          _keyToken: token.trim(),
          _keyRepo: repo.trim(),
        }),
      );
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

  Future<void> clearConfig() async {
    if (Platform.isMacOS) {
      final file = await _getMacConfigFile();
      if (await file.exists()) await file.delete();
      return;
    }
    await _storage.deleteAll();
  }
}
