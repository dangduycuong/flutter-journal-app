import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();
  static const _keyToken = 'github_token';
  static const _keyOwner = 'github_owner';
  static const _keyRepo = 'github_repo';
  static const _keyBiometricLock = 'biometric_lock_enabled';

  Future<void> saveGitHubConfig({
    required String owner,
    required String token,
    String repo = 'my-journal-data',
  }) async {
    await _storage.write(key: _keyOwner, value: owner.trim());
    await _storage.write(key: _keyToken, value: token.trim());
    await _storage.write(key: _keyRepo, value: repo.trim());
  }

  Future<Map<String, String?>> getGitHubConfig() async {
    final owner = await _storage.read(key: _keyOwner);
    final token = await _storage.read(key: _keyToken);
    final repo = await _storage.read(key: _keyRepo) ?? 'my-journal-data';
    return {'owner': owner, 'token': token, 'repo': repo};
  }

  // Bật / Tắt khóa FaceID / Vân tay
  Future<void> setBiometricLockEnabled(bool enabled) async {
    await _storage.write(key: _keyBiometricLock, value: enabled.toString());
  }

  Future<bool> isBiometricLockEnabled() async {
    final val = await _storage.read(key: _keyBiometricLock);
    return val == 'true';
  }

  Future<void> clearConfig() async {
    await _storage.deleteAll();
  }
}
