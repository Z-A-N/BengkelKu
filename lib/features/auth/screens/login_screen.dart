import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reset_password_screen.dart';
import 'register_screen.dart';
import 'vehicle_form_screen.dart';
import '../../home/home_dashboard.dart';

import 'package:bengkelku/features/auth/services/auth_service.dart';
import 'package:bengkelku/widgets/ornamen_Lingkaran.dart';

class Masuk extends StatefulWidget {
  const Masuk({super.key});

  @override
  State<Masuk> createState() => _MasukState();
}

class _MasukState extends State<Masuk> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _rememberMe = false;
  bool _isLoading = false;
  bool _sembunyikanPassword = true;

  String? _emailErrorText;
  String? _passwordErrorText;

  int _lockSeconds = 0;
  Timer? _lockTimer;

  late final AnimationController _pengendaliAnimasi;
  late final Animation<double> _animasiFade;
  late final Animation<Offset> _animasiGeser;

  bool get _isLocked => _lockSeconds > 0;

  String _formatLockRemaining() {
    final minutes = _lockSeconds ~/ 60;
    final seconds = _lockSeconds % 60;

    if (minutes > 0) {
      return "$minutes menit ${seconds.toString().padLeft(2, '0')} dtk";
    }
    return "$seconds dtk";
  }

  @override
  void initState() {
    super.initState();

    _pengendaliAnimasi = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _animasiFade = CurvedAnimation(
      parent: _pengendaliAnimasi,
      curve: Curves.easeInOut,
    );

    _animasiGeser = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _pengendaliAnimasi,
        curve: Curves.easeOutCubic,
      ),
    );

    _pengendaliAnimasi.forward();

    _loadRememberMe();

    _emailController.addListener(() {
      if (_emailErrorText != null && mounted) {
        setState(() => _emailErrorText = null);
      }
    });

    _passwordController.addListener(() {
      if (_passwordErrorText != null && mounted) {
        setState(() => _passwordErrorText = null);
      }
    });
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _pengendaliAnimasi.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString("saved_email");
    final savedRemember = prefs.getBool("remember_me") ?? false;

    if (!mounted) return;

    if (savedEmail != null && savedRemember) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberMe = true;
      });
    }
  }

  void _startLockdown(int seconds) {
    if (!mounted) return;

    setState(() => _lockSeconds = seconds);

    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_lockSeconds <= 1) {
        timer.cancel();
        setState(() => _lockSeconds = 0);
      } else {
        setState(() => _lockSeconds--);
      }
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: isError ? Colors.red.shade700 : null,
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<void> _handleAfterLogin(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_rememberMe && user.email != null) {
        await prefs.setString("saved_email", user.email!);
        await prefs.setBool("remember_me", true);
      } else {
        await prefs.remove("saved_email");
        await prefs.setBool("remember_me", false);
      }

      final hasVehicle = await AuthService.instance.hasVehicleData(user.uid);

      if (!mounted) return;

      if (!hasVehicle) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VehicleFormScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeDashboard()),
        );
      }
    } catch (_) {
      if (!mounted) return;
      _showSnackBar("Gagal memuat data akun. Coba lagi.", isError: true);
    }
  }

  Future<void> _loginWithGoogle() async {
    if (_isLoading || _isLocked) return;

    setState(() => _isLoading = true);
    try {
      final user = await AuthService.instance.signInWithGoogle();
      if (user == null) return; // user cancel

      await _handleAfterLogin(user);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      var msg = "Login Google gagal.";
      var isError = true;

      if (e.code == 'network-request-failed') {
        msg = "Koneksi internet bermasalah.";
      } else if (e.code == 'account-exists-with-different-credential') {
        msg =
            "Email ini sudah terdaftar dengan metode lain. Coba login dengan email & kata sandi.";
        isError = false;
      }

      _showSnackBar(msg, isError: isError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithFacebook() async {
    if (_isLoading || _isLocked) return;

    setState(() => _isLoading = true);
    try {
      final user = await AuthService.instance.signInWithFacebook();
      if (user == null) return; // user cancel

      await _handleAfterLogin(user);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      var msg = "Login Facebook gagal.";

      if (e.code == 'network-request-failed') {
        msg = "Koneksi internet bermasalah.";
      } else if (e.code == 'facebook-no-token') {
        msg = "Gagal mendapatkan token Facebook. Coba lagi.";
      } else if (e.code == 'facebook-login-failed') {
        msg = "Login Facebook gagal. Coba lagi.";
      }

      _showSnackBar(msg, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginUser() async {
    if (_isLoading || _isLocked) return;

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _emailErrorText = null;
      _passwordErrorText = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final user = await AuthService.instance.login(
        email: email,
        password: password,
      );

      await _handleAfterLogin(user!);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String? snackMessage;

      setState(() {
        _emailErrorText = null;
        _passwordErrorText = null;

        switch (e.code) {
          case "invalid-email":
            _emailErrorText = "Format email salah";
            break;

          case "user-not-found":
          case "wrong-password":
          case "invalid-credential":
            _passwordErrorText = "Email atau kata sandi salah";
            break;

          case "too-many-requests":
            snackMessage =
                "Terlalu banyak percobaan gagal. Silakan coba lagi nanti atau reset kata sandi.";
            _startLockdown(1800);
            break;

          case "network-request-failed":
            snackMessage = "Koneksi internet bermasalah.";
            break;

          default:
            snackMessage = "Terjadi kesalahan. Coba lagi.";
        }
      });

      if (snackMessage != null) {
        _showSnackBar(snackMessage!, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            const OrnamenSetengahLingkaranAtas(),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 500.w),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 25.h),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: 0.05.sh),

                        FadeTransition(
                          opacity: _animasiFade,
                          child: SlideTransition(
                            position: _animasiGeser,
                            child: Image.asset(
                              'assets/logo.png',
                              width: 90.w,
                              height: 90.w,
                            ),
                          ),
                        ),

                        SizedBox(height: 25.h),

                        FadeTransition(
                          opacity: _animasiFade,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: "Masuk ke akun\n",
                                    style: TextStyle(
                                      fontSize: 26.sp,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  TextSpan(
                                    text: "Anda",
                                    style: TextStyle(
                                      fontSize: 26.sp,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFDB0C0C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 8.h),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Masukkan email dan kata sandi untuk masuk",
                            style: TextStyle(color: Colors.black54, fontSize: 15.sp),
                          ),
                        ),

                        SizedBox(height: 25.h),

                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (v) {
                            if (v == null || v.isEmpty) return "Email wajib diisi";
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim())) {
                              return "Email tidak valid";
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: "Email",
                            hintText: "contoh@gmail.com",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            prefixIcon: const Icon(Icons.email_outlined),
                            errorText: _emailErrorText,
                          ),
                        ),

                        SizedBox(height: 18.h),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: _sembunyikanPassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _loginUser(),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (v) {
                            if (v == null || v.isEmpty) return "Kata sandi wajib diisi";
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: "Kata Sandi",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _sembunyikanPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _sembunyikanPassword = !_sembunyikanPassword;
                                });
                              },
                            ),
                            errorText: _passwordErrorText,
                          ),
                        ),

                        SizedBox(height: 10.h),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  onChanged: (v) =>
                                      setState(() => _rememberMe = v ?? false),
                                  activeColor: const Color(0xFFDB0C0C),
                                ),
                                Text("Ingat saya", style: TextStyle(fontSize: 14.sp)),
                              ],
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LupaKataSandi()),
                                );
                              },
                              child: Text(
                                "Lupa kata sandi?",
                                style: TextStyle(
                                  color: const Color(0xFFDB0C0C),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 15.h),

                        SizedBox(
                          width: double.infinity,
                          height: 48.h,
                          child: ElevatedButton(
                            onPressed: (_isLoading || _isLocked) ? null : _loginUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDB0C0C),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  )
                                : Text(
                                    _isLocked
                                        ? "Coba lagi dalam ${_formatLockRemaining()}"
                                        : "Masuk",
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),

                        SizedBox(height: 20.h),

                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8.w),
                              child: Text("Atau", style: TextStyle(fontSize: 14.sp)),
                            ),
                            Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                          ],
                        ),

                        SizedBox(height: 20.h),

                        _tombolSosial(
                          'Lanjut dengan Google',
                          'assets/google.webp',
                          _loginWithGoogle,
                        ),
                        SizedBox(height: 15.h),
                        _tombolSosial(
                          'Lanjut dengan Facebook',
                          'assets/fb.webp',
                          _loginWithFacebook,
                        ),

                        SizedBox(height: 25.h),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Belum punya akun? ", style: TextStyle(fontSize: 14.sp)),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const Daftar()),
                                );
                              },
                              child: Text(
                                "Daftar",
                                style: TextStyle(
                                  color: const Color(0xFFDB0C0C),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tombolSosial(String teks, String pathIkon, VoidCallback onPressed) {
    final disabled = _isLoading || _isLocked;

    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: OutlinedButton.icon(
        icon: Image.asset(pathIkon, width: 22.w),
        onPressed: disabled ? null : onPressed,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        label: Text(
          teks,
          style: TextStyle(
            fontSize: 15.sp,
            color: disabled ? Colors.grey : Colors.black87,
          ),
        ),
      ),
    );
  }
}
