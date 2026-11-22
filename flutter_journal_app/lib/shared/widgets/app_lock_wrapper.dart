import 'package:local_auth/local_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/services/storage_service.dart';

class AppLockWrapper extends StatefulWidget {
  final Widget child;
  const AppLockWrapper({super.key, required this.child});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper>
    with WidgetsBindingObserver {
  final _auth = LocalAuthentication();
  final _storage = StorageService();
  bool _isLocked = false;
  bool _isChecking = true;
  bool _isAuthenticating = false; // Cờ chặn gọi trùng lặp FaceID

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndAuthenticate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    // Bỏ qua sự kiện vòng đời nếu hộp thoại FaceID đang mở
    if (_isAuthenticating) return;

    if (state == AppLifecycleState.paused) {
      final enabled = await _storage.isBiometricLockEnabled();
      if (enabled && mounted) {
        setState(() => _isLocked = true);
      }
    } else if (state == AppLifecycleState.resumed && _isLocked) {
      _authenticate();
    }
  }

  Future<void> _checkAndAuthenticate() async {
    final enabled = await _storage.isBiometricLockEnabled();
    if (!enabled) {
      if (mounted) {
        setState(() {
          _isLocked = false;
          _isChecking = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLocked = true;
        _isChecking = false;
      });
    }
    await _authenticate();
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;

    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Xác thực để mở khóa Nhật ký & Tâm đắc',
        persistAcrossBackgrounding: true,
        biometricOnly: false,
      );
      if (didAuthenticate && mounted) {
        setState(() => _isLocked = false);
      }
    } catch (e) {
      debugPrint('Lỗi xác thực sinh trắc học: $e');
    } finally {
      // Đợi 500ms sau khi hộp thoại hệ thống đóng hẳn mới mở lại cờ
      await Future.delayed(const Duration(milliseconds: 500));
      _isAuthenticating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isLocked) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nhật ký đã được khóa',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Xác thực bằng FaceID, vân tay hoặc mật mã thiết bị để tiếp tục.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _authenticate,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Mở khóa ngay'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
