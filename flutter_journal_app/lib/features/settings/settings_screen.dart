import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;

import '../../core/services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onConfigSaved;
  const SettingsScreen({super.key, this.onConfigSaved});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = StorageService();
  final _ownerController = TextEditingController();
  final _repoController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _biometricEnabled = false;
  bool _hasAppPin = false;
  bool _isLoading = false;
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _repoController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    final config = await _storage.getGitHubConfig();
    final bio = await _storage.isBiometricLockEnabled();
    final pin = await _storage.getAppPin();
    if (!mounted) return;
    setState(() {
      _ownerController.text = config['owner'] ?? '';
      _repoController.text = config['repo'] ?? 'my-journal-data';
      _tokenController.text = config['token'] ?? '';
      _biometricEnabled = bio;
      _hasAppPin = pin != null && pin.isNotEmpty;
    });
  }

  Widget _buildClearButton(TextEditingController controller, String tooltip) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        if (value.text.isEmpty) return const SizedBox.shrink();
        return IconButton(
          icon: const Icon(Icons.close, size: 20),
          tooltip: tooltip,
          onPressed: () => controller.clear(),
        );
      },
    );
  }

  Future<void> _showSetPinDialog() async {
    final pinController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_hasAppPin ? 'Đổi mã PIN 6 số' : 'Đặt mã PIN 6 số'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Nhập 6 chữ số',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          if (_hasAppPin)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'REMOVE'),
              child: const Text(
                'Tắt mã PIN',
                style: TextStyle(color: Colors.red),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (pinController.text.length == 6) {
                Navigator.pop(ctx, pinController.text);
              }
            },
            child: const Text('Lưu PIN'),
          ),
        ],
      ),
    );

    if (result == 'REMOVE') {
      await _storage.setAppPin(null);
      if (!mounted) return;
      setState(() => _hasAppPin = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã tắt mã PIN ứng dụng')));
    } else if (result != null && result.length == 6) {
      await _storage.setAppPin(result);
      if (!mounted) return;
      setState(() => _hasAppPin = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu mã PIN 6 số thành công!')),
      );
    }
  }

  Future<void> _testAndSave() async {
    final owner = _ownerController.text.trim();
    final repo = _repoController.text.trim();
    final token = _tokenController.text.trim();

    if (owner.isEmpty || repo.isEmpty || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin GitHub')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final host = ['api', 'github', 'com'].join('.');
      final url = Uri.https(host, '/repos/$owner/$repo');
      final res = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'User-Agent': 'Flutter-Journal-App',
        },
      );

      if (res.statusCode == 200) {
        await _storage.saveGitHubConfig(owner: owner, repo: repo, token: token);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kết nối GitHub thành công!')),
        );
        widget.onConfigSaved?.call();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lỗi kết nối (${res.statusCode}): Kiểm tra lại Token hoặc tên Repo',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi mạng: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cài đặt',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Cấu hình GitHub Private Repository',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ownerController,
            decoration: InputDecoration(
              labelText: 'GitHub Username (Owner)',
              border: const OutlineInputBorder(),
              suffixIcon: _buildClearButton(_ownerController, 'Xóa Username'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _repoController,
            decoration: InputDecoration(
              labelText: 'Tên Repository (mặc định: my-journal-data)',
              border: const OutlineInputBorder(),
              suffixIcon: _buildClearButton(_repoController, 'Xóa tên Repo'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tokenController,
            obscureText: _obscureToken,
            decoration: InputDecoration(
              labelText: 'Personal Access Token (PAT)',
              border: const OutlineInputBorder(),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildClearButton(_tokenController, 'Xóa Token'),
                  IconButton(
                    icon: Icon(
                      _obscureToken ? Icons.visibility : Icons.visibility_off,
                    ),
                    tooltip: _obscureToken ? 'Hiện Token' : 'Ẩn Token',
                    onPressed: () =>
                        setState(() => _obscureToken = !_obscureToken),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isLoading ? null : _testAndSave,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            label: const Text('Kiểm tra & Lưu cấu hình'),
          ),

          if (!Platform.isMacOS) ...[
            const Divider(height: 32),
            const Text(
              'Bảo mật ứng dụng',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.pin_outlined),
              title: Text(
                _hasAppPin
                    ? 'Đổi mã PIN 6 số (Đang bật)'
                    : 'Đặt mã PIN 6 số dự phòng',
              ),
              subtitle: const Text(
                'Mở khóa nhanh bằng mã PIN riêng ngay trong app',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showSetPinDialog,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.fingerprint),
              title: const Text('Quét vân tay / FaceID khi mở app'),
              subtitle: const Text('Tự động gọi cảm biến sinh trắc học'),
              value: _biometricEnabled,
              onChanged: (val) async {
                await _storage.setBiometricLockEnabled(val);
                setState(() => _biometricEnabled = val);
              },
            ),
            const Divider(height: 32),
            const Text(
              'Giao diện & Hiển thị',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<double>(
              valueListenable: StorageService.fontScaleNotifier,
              builder: (context, scale, _) {
                final percent = (scale * 100).round();
                return Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.format_size),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Cỡ chữ ứng dụng',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                'Hiện tại: $percent% (Mỗi lần ±5%)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.outlined(
                          icon: const Icon(Icons.remove),
                          tooltip: 'Giảm 5%',
                          onPressed: scale <= 0.85
                              ? null
                              : () => _storage.setFontScale(scale - 0.05),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          icon: const Icon(Icons.add),
                          tooltip: 'Tăng 5%',
                          onPressed: scale >= 1.50
                              ? null
                              : () => _storage.setFontScale(scale + 0.05),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
