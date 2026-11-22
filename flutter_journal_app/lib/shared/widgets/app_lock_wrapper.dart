import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

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

  String? _savedPin;
  String _enteredPin = '';
  bool _pinError = false;
  final _createPinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndAuthenticate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _createPinController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (Platform.isMacOS || _isAuthenticating) return;

    if (state == AppLifecycleState.paused) {
      final bioEnabled = await _storage.isBiometricLockEnabled();
      final pin = await _storage.getAppPin();
      if ((bioEnabled || (pin != null && pin.isNotEmpty)) && mounted) {
        setState(() {
          _savedPin = pin;
          _enteredPin = '';
          _pinError = false;
          _isLocked = true;
        });
      }
    }
  }

  Future<void> _checkAndAuthenticate() async {
    if (Platform.isMacOS) {
      if (mounted) {
        setState(() {
          _isLocked = false;
          _isChecking = false;
        });
      }
      return;
    }

    final bioEnabled = await _storage.isBiometricLockEnabled();
    final pin = await _storage.getAppPin();
    final hasPin = pin != null && pin.isNotEmpty;

    if (!bioEnabled && !hasPin) {
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
        _savedPin = pin;
        _enteredPin = '';
        _pinError = false;
        _isLocked = true;
        _isChecking = false;
      });
    }

    if (bioEnabled && hasPin) {
      await _authenticateBiometric();
    }
  }

  Future<void> _authenticateBiometric() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;

    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck && !isSupported) return;

      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Quét vân tay để mở khóa hoặc ấn Hủy để nhập PIN',
        persistAcrossBackgrounding: true,
        biometricOnly: true,
      );

      if (didAuthenticate && mounted) {
        setState(() {
          _isLocked = false;
          _enteredPin = '';
        });
      }
    } catch (e) {
      debugPrint('Lỗi sinh trắc học: $e');
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      _isAuthenticating = false;
    }
  }

  void _onDigitPress(String digit) {
    if (_savedPin == null || _enteredPin.length >= 6) return;

    setState(() {
      _pinError = false;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 6) {
      if (_enteredPin == _savedPin) {
        setState(() {
          _isLocked = false;
          _enteredPin = '';
        });
      } else {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) {
            setState(() {
              _pinError = true;
              _enteredPin = '';
            });
          }
        });
      }
    }
  }

  void _onBackspacePress() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _pinError = false;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  Widget _buildKeyButton(String label, {VoidCallback? onTap, Widget? child}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: label.isNotEmpty
              ? Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5)
              : Colors.transparent,
        ),
        child:
            child ??
            Text(
              label,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isLocked) {
      final hasPin = _savedPin != null && _savedPin!.isNotEmpty;
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nhật ký đã được khóa',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (hasPin) ...[
                    Text(
                      _pinError
                          ? 'Mã PIN không đúng, vui lòng thử lại'
                          : 'Nhập mã PIN 6 số để mở khóa',
                      style: TextStyle(
                        color: _pinError ? Colors.red : Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        final filled = index < _enteredPin.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 7),
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _pinError
                                ? Colors.red
                                : (filled
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent),
                            border: Border.all(
                              color: _pinError
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildKeyButton(
                              '1',
                              onTap: () => _onDigitPress('1'),
                            ),
                            _buildKeyButton(
                              '2',
                              onTap: () => _onDigitPress('2'),
                            ),
                            _buildKeyButton(
                              '3',
                              onTap: () => _onDigitPress('3'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildKeyButton(
                              '4',
                              onTap: () => _onDigitPress('4'),
                            ),
                            _buildKeyButton(
                              '5',
                              onTap: () => _onDigitPress('5'),
                            ),
                            _buildKeyButton(
                              '6',
                              onTap: () => _onDigitPress('6'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildKeyButton(
                              '7',
                              onTap: () => _onDigitPress('7'),
                            ),
                            _buildKeyButton(
                              '8',
                              onTap: () => _onDigitPress('8'),
                            ),
                            _buildKeyButton(
                              '9',
                              onTap: () => _onDigitPress('9'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildKeyButton(
                              '',
                              onTap: _authenticateBiometric,
                              child: Icon(
                                Icons.fingerprint,
                                size: 32,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            _buildKeyButton(
                              '0',
                              onTap: () => _onDigitPress('0'),
                            ),
                            _buildKeyButton(
                              '',
                              onTap: _onBackspacePress,
                              child: const Icon(
                                Icons.backspace_outlined,
                                size: 26,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ] else ...[
                    const Text(
                      'Cảm biến vân tay không khả dụng. Hãy tạo mã PIN 6 số dự phòng để mở khóa ngay:',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _createPinController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, letterSpacing: 10),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          hintText: '••••••',
                          counterText: '',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () async {
                        final newPin = _createPinController.text.trim();
                        if (newPin.length == 6) {
                          await _storage.setAppPin(newPin);
                          await _storage.setBiometricLockEnabled(false);
                          if (mounted) {
                            setState(() {
                              _savedPin = newPin;
                              _isLocked = false;
                            });
                          }
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Lưu PIN & Mở khóa ngay'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }
    return widget.child;
  }
}
