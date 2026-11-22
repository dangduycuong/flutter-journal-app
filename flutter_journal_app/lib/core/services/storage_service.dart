import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();
  static const _keyToken = 'github_token';
  static const _keyOwner = 'github_owner';
  static const _keyRepo = 'github_repo';

  // Lưu thông tin cấu hình GitHub
  Future<void> saveGitHubConfig({
    required String owner,
    required String token,
    String repo = 'my-journal-data',
  }) async {
    await _storage.write(key: _keyOwner, value: owner.trim());
    await _storage.write(key: _keyToken, value: token.trim());
    await _storage.write(key: _keyRepo, value: repo.trim());
  }

  // Đọc thông tin cấu hình
  Future<Map<String, String?>> getGitHubConfig() async {
    final owner = await _storage.read(key: _keyOwner);
    final token = await _storage.read(key: _keyToken);
    final repo = await _storage.read(key: _keyRepo) ?? 'my-journal-data';
    return {'owner': owner, 'token': token, 'repo': repo};
  }

  // Xóa cấu hình (khi muốn đổi tài khoản/token)
  Future<void> clearConfig() async {
    await _storage.deleteAll();
  }
}
