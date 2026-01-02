// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bengkelku/features/auth/services/auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Visibility
  bool _hideOldPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;

  // State
  bool _hasPassword = false; // apakah akun sudah punya password
  bool _saving = false;
  bool _sendingReset = false;

  // Error khusus per field
  String? _oldPasswordError;
  String? _newPasswordError;

  // ================= LOCKDOWN (persisten) =================
  int _lockSeconds = 0;
  Timer? _lockTimer;
  bool _lockInitialized = false; // biar tidak flicker saat restore

  bool get _isLocked => _lockSeconds > 0;

  static const _lockKey = 'change_password_locked_until';

  String _formatLockRemaining() {
    final minutes = _lockSeconds ~/ 60;
    final seconds = _lockSeconds % 60;

    if (minutes > 0) {
      return "$minutes menit ${seconds.toString().padLeft(2, '0')} dtk";
    } else {
      return "$seconds dtk";
    }
  }

  Future<void> _restoreLockdown() async {
    final prefs = await SharedPreferences.getInstance();
    final lockedUntilMillis = prefs.getInt(_lockKey);

    if (!mounted) return;

    if (lockedUntilMillis == null) {
      setState(() {
        _lockSeconds = 0;
        _lockInitialized = true;
      });
      return;
    }

    final lockedUntil = DateTime.fromMillisecondsSinceEpoch(lockedUntilMillis);
    final now = DateTime.now();

    if (lockedUntil.isAfter(now)) {
      final remaining = lockedUntil.difference(now).inSeconds;
      // set _lockSeconds & jalanin timer (lockInitialized masih false → tombol disabled)
      _startLockdown(remaining, persist: false);
    } else {
      // sudah lewat masa lock
      await prefs.remove(_lockKey);
      setState(() {
        _lockSeconds = 0;
      });
    }

    if (mounted) {
      setState(() {
        _lockInitialized = true;
      });
    }
  }

  void _startLockdown(int seconds, {bool persist = true}) async {
    setState(() {
      _lockSeconds = seconds;
    });

    final prefs = await SharedPreferences.getInstance();
    if (persist) {
      final lockedUntil = DateTime.now()
          .add(Duration(seconds: seconds))
          .millisecondsSinceEpoch;
      await prefs.setInt(_lockKey, lockedUntil);
    }

    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_lockSeconds <= 1) {
        timer.cancel();
        if (!mounted) return;
        setState(() {
          _lockSeconds = 0;
        });
        await prefs.remove(_lockKey);
      } else {
        if (!mounted) return;
        setState(() {
          _lockSeconds--;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();

    // pakai helper dari AuthService
    _hasPassword = AuthService.instance.currentUserHasPasswordProvider;

    // restore state lockdown kalau sebelumnya sudah ke-lock
    _restoreLockdown();
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ================= HELPER UI =================

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: isError
              ? Colors.red.shade700
              : Colors.green.shade600,
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      errorText: errorText,
    );
  }

  // ================= RESET PASSWORD VIA EMAIL =================

  Future<void> _sendResetPassword() async {
    if (_sendingReset) return;

    setState(() => _sendingReset = true);

    try {
      final user = AuthService.instance.currentUser;
      if (user == null || user.email == null) {
        _showSnackBar('User tidak ditemukan. Silakan login ulang.');
        return;
      }

      await AuthService.instance.sendResetPasswordEmail(user.email!);

      if (!mounted) return;

      _showSnackBar(
        'Link reset kata sandi telah dikirim ke ${user.email}',
        isError: false,
      );
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Gagal mengirim email reset. Coba lagi.', isError: true);
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  // ================= UBAH / BUAT KATA SANDI =================

  Future<void> _changePassword() async {
    if (_saving || _isLocked) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
      _oldPasswordError = null;
      _newPasswordError = null;
    });

    try {
      final hadPasswordBefore = await AuthService.instance
          .changeOrCreatePassword(
            oldPassword: _hasPassword
                ? _oldPasswordController.text.trim()
                : null,
            newPassword: _newPasswordController.text.trim(),
          );

      if (!mounted) return;

      _showSnackBar(
        hadPasswordBefore
            ? 'Kata sandi berhasil diubah.'
            : 'Kata sandi berhasil dibuat. Mulai sekarang kamu bisa login pakai email & kata sandi.',
        isError: false,
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      // reset error dulu
      setState(() {
        _oldPasswordError = null;
        _newPasswordError = null;
      });

      // 🔴 SEMUA error kredensial lama → error di field "kata sandi lama"
      if (_hasPassword &&
          (e.code == 'wrong-password' || e.code == 'invalid-credential')) {
        setState(() {
          _oldPasswordError = 'Kata sandi salah';
        });
        return;
      }

      String? fieldMessage;
      String? snackMessage;

      switch (e.code) {
        case 'weak-password':
          fieldMessage = 'Kata sandi baru terlalu lemah.';
          break;

        case 'missing-old-password':
          if (_hasPassword) {
            fieldMessage = 'Kata sandi lama wajib diisi';
          } else {
            snackMessage =
                'Terjadi kesalahan. Silakan muat ulang dan coba lagi.';
          }
          break;

        case 'no-user':
          snackMessage = 'User tidak ditemukan. Silakan login ulang.';
          break;

        case 'requires-recent-login':
          snackMessage =
              'Demi keamanan, silakan login ulang lalu coba ubah kata sandi lagi.';
          break;

        case 'too-many-requests':
          snackMessage =
              'Terlalu banyak percobaan gagal. Coba lagi nanti atau reset kata sandi.';
          _startLockdown(1800);
          break;

        case 'network-request-failed':
          snackMessage = 'Koneksi internet bermasalah.';
          break;

        default:
          snackMessage =
              'Terjadi kesalahan saat mengubah kata sandi. Coba lagi beberapa saat lagi.';
      }

      if (fieldMessage != null) {
        setState(() {
          _newPasswordError = fieldMessage;
        });
      }

      if (snackMessage != null) {
        _showSnackBar(snackMessage, isError: true);
      }
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Gagal mengubah kata sandi. Coba lagi.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    // sebelum lockInitialized true → selalu disabled biar nggak flicker
    final bool isButtonDisabled = _saving || !_lockInitialized || _isLocked;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Ubah Kata Sandi',
            style: TextStyle(color: Colors.black),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ========== INFO + LUPA KATA SANDI (di atas form) ==========
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _hasPassword
                              ? 'Kamu login dengan email & kata sandi. Untuk mengganti kata sandi, masukkan kata sandi lama terlebih dahulu.'
                              : 'Kamu login menggunakan Google / Facebook. Di sini kamu bisa membuat kata sandi baru agar bisa login memakai email & kata sandi juga.',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.black87,
                          ),
                        ),
                        if (_hasPassword) ...[
                          SizedBox(height: 6.h),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _sendingReset
                                  ? null
                                  : _sendResetPassword,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                _sendingReset
                                    ? 'Mengirim...'
                                    : 'Lupa kata sandi?',
                                style: const TextStyle(
                                  color: Color(0xFFDB0C0C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // ========== CARD FORM PASSWORD ==========
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (_hasPassword) ...[
                          // ========== KATA SANDI LAMA ==========
                          TextFormField(
                            controller: _oldPasswordController,
                            obscureText: _hideOldPassword,
                            decoration: _inputDecoration(
                              label: 'Kata sandi lama',
                              icon: Icons.lock_outline,
                              suffix: IconButton(
                                icon: Icon(
                                  _hideOldPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _hideOldPassword = !_hideOldPassword;
                                  });
                                },
                              ),
                              errorText: _oldPasswordError,
                            ),
                            onChanged: (_) {
                              if (_oldPasswordError != null) {
                                setState(() => _oldPasswordError = null);
                              }
                            },
                            validator: (v) {
                              if (!_hasPassword) return null;
                              if (v == null || v.isEmpty) {
                                return 'Kata sandi lama wajib diisi';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16.h),
                        ],

                        // ========== KATA SANDI BARU ==========
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: _hideNewPassword,
                          decoration: _inputDecoration(
                            label: 'Kata sandi baru',
                            icon: Icons.lock_reset_outlined,
                            suffix: IconButton(
                              icon: Icon(
                                _hideNewPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _hideNewPassword = !_hideNewPassword;
                                });
                              },
                            ),
                          ).copyWith(errorText: _newPasswordError),
                          onChanged: (_) {
                            if (_newPasswordError != null) {
                              setState(() => _newPasswordError = null);
                            }
                          },
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Kata sandi baru wajib diisi';
                            }
                            if (v.length < 6) {
                              return 'Minimal 6 karakter';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16.h),

                        // ========== KONFIRMASI KATA SANDI BARU ==========
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _hideConfirmPassword,
                          decoration: _inputDecoration(
                            label: 'Konfirmasi kata sandi baru',
                            icon: Icons.lock_person_outlined,
                            suffix: IconButton(
                              icon: Icon(
                                _hideConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _hideConfirmPassword = !_hideConfirmPassword;
                                });
                              },
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Konfirmasi kata sandi wajib diisi';
                            }
                            if (v.trim() !=
                                _newPasswordController.text.trim()) {
                              return 'Konfirmasi kata sandi tidak cocok';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 32.h),

                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: isButtonDisabled ? null : _changePassword,
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.resolveWith((
                          states,
                        ) {
                          if (states.contains(MaterialState.disabled)) {
                            return Colors.grey.shade400;
                          }
                          return const Color(0xFFDB0C0C);
                        }),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _isLocked
                                  ? 'Coba lagi dalam ${_formatLockRemaining()}'
                                  : 'Simpan Kata Sandi',
                              style: const TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
