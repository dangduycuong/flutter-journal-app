import 'dart:io';

import 'package:flutter/services.dart';
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
  bool _isAuthenticating = false;
  String? _errorMessage;

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
    if (_isAuthenticating) return;

    if (state == AppLifecycleState.paused) {
      final enabled = await _storage.isBiometricLockEnabled();
      if (enabled && mounted) {
        setState(() {
          _isLocked = true;
          _errorMessage = null;
        });
      }
    } else if (state == AppLifecycleState.resumed && _isLocked) {
      _authenticate();
    }
  }

  Future<void> _checkAndAuthenticate() async {
    // Trên macOS (MacBook), bỏ qua khóa sinh trắc học để tránh xung đột Sandbox
    if (Platform.isMacOS) {
      if (mounted) {
        setState(() {
          _isLocked = false;
          _isChecking = false;
        });
      }
      return;
    }
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
    setState(() => _errorMessage = null);

    try {
      // Kiểm tra xem thiết bị có hỗ trợ xác thực nào không (vân tay, khuôn mặt hoặc PIN/mật khẩu)
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();

      if (!canCheckBiometrics && !isDeviceSupported) {
        if (mounted) {
          setState(() {
            _isLocked = false;
          });
        }
        return;
      }

      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Quét vân tay hoặc nhập mật khẩu thiết bị để mở khóa',
        persistAcrossBackgrounding: true,
        biometricOnly:
            false, // Cho phép chuyển sang PIN/mật khẩu/hình vẽ của máy
      );

      if (didAuthenticate && mounted) {
        setState(() {
          _isLocked = false;
          _errorMessage = null;
        });
      }
    } on PlatformException catch (e) {
      debugPrint('Lỗi PlatformException xác thực: ${e.code} - ${e.message}');
      if (mounted) {
        setState(() {
          _errorMessage =
              'Vân tay không nhận diện được (${e.code}). Bạn có thể thử lại hoặc nhập mật khẩu máy.';
        });
      }
    } catch (e) {
      debugPrint('Lỗi xác thực sinh trắc học: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Không thể xác thực vân tay. Vui lòng thử lại.';
        });
      }
    } finally {
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
                  'Xác thực bằng vân tay, khuôn mặt hoặc mật mã thiết bị để tiếp tục.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
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
