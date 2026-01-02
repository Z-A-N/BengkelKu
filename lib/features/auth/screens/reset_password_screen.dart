// ignore_for_file: deprecated_member_use, unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bengkelku/widgets/ornamen_Lingkaran.dart';
import 'package:bengkelku/features/auth/services/auth_service.dart';

class LupaKataSandi extends StatefulWidget {
  const LupaKataSandi({super.key});

  @override
  State<LupaKataSandi> createState() => _LupaKataSandiState();
}

class _LupaKataSandiState extends State<LupaKataSandi>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  String? _emailErrorText;
  bool _isLoading = false;

  late AnimationController _animCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _animCtrl.forward();

    _emailController.addListener(() {
      if (_emailErrorText != null) {
        setState(() => _emailErrorText = null);
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ===============================================================
  // SNACKBAR
  // ===============================================================
  void _showSnackBar(String message, {bool isError = false}) {
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
              : const Color(0xFF27AE60),
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ===============================================================
  // RESET PASSWORD (FIX + Firestore Check)
  // ===============================================================
  Future<void> _kirimLinkReset() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();

    setState(() {
      _isLoading = true;
      _emailErrorText = null;
    });

    // Cek email di Firestore
    final exists = await AuthService.instance.emailExists(email);

    if (!exists) {
      setState(() {
        _emailErrorText = "Email tidak ditemukan";
        _isLoading = false;
      });
      return;
    }

    try {
      await AuthService.instance.sendResetPasswordEmail(email);

      _showSnackBar(
        "Tautan reset telah dikirim ke email kamu.",
        isError: false,
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case "invalid-email":
          setState(() => _emailErrorText = "Format email salah");
          break;

        case "network-request-failed":
          _showSnackBar("Koneksi internet bermasalah.", isError: true);
          break;

        default:
          _showSnackBar("Terjadi kesalahan. Coba lagi.", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===============================================================
  // UI
  // ===============================================================
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              const OrnamenSetengahLingkaranAtas(),

              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 500.w),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: 28.w,
                      vertical: 25.h,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          SizedBox(height: 0.05.sh),

                          FadeTransition(
                            opacity: _fade,
                            child: SlideTransition(
                              position: _slide,
                              child: Image.asset(
                                'assets/logo.png',
                                width: 90.w,
                                height: 90.w,
                              ),
                            ),
                          ),

                          SizedBox(height: 25.h),

                          FadeTransition(
                            opacity: _fade,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: "Reset\n",
                                      style: TextStyle(
                                        fontSize: 26.sp,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    TextSpan(
                                      text: "Kata Sandi",
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
                              "Masukkan email kamu untuk menerima tautan reset kata sandi.",
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 15.sp,
                              ),
                            ),
                          ),

                          SizedBox(height: 25.h),

                          FadeTransition(
                            opacity: _fade,
                            child: SlideTransition(
                              position: _slide,
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return "Email wajib diisi";
                                  }
                                  final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                                  if (!regex.hasMatch(v.trim())) {
                                    return "Format email tidak valid";
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
                            ),
                          ),

                          SizedBox(height: 25.h),

                          FadeTransition(
                            opacity: _fade,
                            child: SlideTransition(
                              position: _slide,
                              child: SizedBox(
                                width: double.infinity,
                                height: 48.h,
                                child: ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _kirimLinkReset,
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
                                          "Kirim Tautan Reset",
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 20.h),

                          FadeTransition(
                            opacity: _fade,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Ingat kata sandimu? ",
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: Colors.black87,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Text(
                                    "Masuk Sekarang",
                                    style: TextStyle(
                                      color: const Color(0xFFDB0C0C),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }
}
