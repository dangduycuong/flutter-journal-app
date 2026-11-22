import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;

import '../../core/services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onConfigSaved;
  const SettingsScreen({super.key, required this.onConfigSaved});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = StorageService();
  final _ownerController = TextEditingController();
  final _repoController = TextEditingController(text: 'my-journal-data');
  final _tokenController = TextEditingController();

  bool _isTesting = false;
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    // Lắng nghe thay đổi để tự động ẩn/hiện nút X trên từng ô
    _ownerController.addListener(() => setState(() {}));
    _repoController.addListener(() => setState(() {}));
    _tokenController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _repoController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await _storage.getGitHubConfig();
    setState(() {
      _ownerController.text = config['owner'] ?? '';
      _repoController.text = config['repo'] ?? 'my-journal-data';
      _tokenController.text = config['token'] ?? '';
    });
  }

  Future<void> _save() async {
    final owner = _ownerController.text.trim();
    final repo = _repoController.text.trim();
    final token = _tokenController.text.trim();

    if (owner.isEmpty || token.isEmpty || repo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập đủ Username, Repo và Token'),
        ),
      );
      return;
    }

    setState(() => _isTesting = true);

    try {
      final testUrl = Uri.parse('https://github.com');
      debugPrint('=== KIỂM TRA KẾT NỐI GITHUB ===');
      debugPrint('URL gọi: $testUrl');
      debugPrint('Độ dài Token: ${token.length} ký tự');

      final res = await http.get(
        testUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'User-Agent': 'Flutter-Journal-App',
        },
      );

      debugPrint('Mã phản hồi HTTP: ${res.statusCode}');
      debugPrint('Nội dung phản hồi: ${res.body}');
      debugPrint('===============================');

      if (res.statusCode == 200) {
        await _storage.saveGitHubConfig(owner: owner, repo: repo, token: token);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kết nối thành công! Đã lưu cấu hình.'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onConfigSaved();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lỗi HTTP ${res.statusCode}: Xem chi tiết ở Debug Console VS Code',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('=== LỖI NGOẠI LỆ KHI LƯU CẤU HÌNH ===');
      debugPrint('Lỗi: $e');
      debugPrint('StackTrace: $stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cấu hình GitHub')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _ownerController,
            decoration: InputDecoration(
              labelText: 'GitHub Username (Owner)',
              border: const OutlineInputBorder(),
              suffixIcon: _ownerController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _ownerController.clear(),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _repoController,
            decoration: InputDecoration(
              labelText: 'Tên Repository dữ liệu',
              border: const OutlineInputBorder(),
              suffixIcon: _repoController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _repoController.clear(),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tokenController,
            obscureText: _obscureToken,
            decoration: InputDecoration(
              labelText: 'Personal Access Token',
              border: const OutlineInputBorder(),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _obscureToken ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscureToken = !_obscureToken),
                  ),
                  if (_tokenController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _tokenController.clear(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isTesting ? null : _save,
            icon: _isTesting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(
              _isTesting
                  ? 'Đang kiểm tra kết nối...'
                  : 'Kiểm tra & Lưu cấu hình',
            ),
          ),
        ],
      ),
    );
  }
}
