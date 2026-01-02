// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'package:bengkelku/features/auth/services/auth_service.dart';
import 'package:bengkelku/widgets/ornamen_Lingkaran.dart';

class Daftar extends StatefulWidget {
  const Daftar({super.key});

  @override
  State<Daftar> createState() => _DaftarState();
}

class _DaftarState extends State<Daftar> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // UI state
  bool _sembunyikanPassword = true;
  bool _sembunyikanKonfirmasi = true;
  bool _isLoading = false;
  String? _emailErrorText;

  // Strength state
  double _strengthValue = 0;
  Color _strengthColor = Colors.grey;
  String _strengthLabel = "";

  // Controllers
  late final TextEditingController _namaController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _konfirmasiController;

  // Focus node
  late final FocusNode _passwordFocusNode;

  // Animations
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _namaController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _konfirmasiController = TextEditingController();

    _passwordFocusNode = FocusNode()
      ..addListener(() {
        if (mounted) setState(() {});
      });

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );

    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _animController.forward();

    _emailController.addListener(() {
      if (_emailErrorText != null && mounted) {
        setState(() => _emailErrorText = null);
      }
    });

    _passwordController.addListener(() {
      _updatePasswordStrength(_passwordController.text);
    });

    _konfirmasiController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _namaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _konfirmasiController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // -------------------------------------------
  // LOGIC VALIDASI
  // -------------------------------------------

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }

  void _updatePasswordStrength(String p) {
    double v;
    Color c;
    String label;

    if (p.isEmpty) {
      v = 0;
      c = Colors.grey;
      label = "";
    } else if (RegExp(
      r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[-!@#\$%^&*]).{8,}$',
    ).hasMatch(p)) {
      v = 1;
      c = Colors.green;
      label = "Kuat";
    } else if (RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{6,}$').hasMatch(p)) {
      v = 0.5;
      c = Colors.orangeAccent;
      label = "Sedang";
    } else {
      v = 0.25;
      c = Colors.redAccent;
      label = "Lemah";
    }

    if (!mounted) return;
    setState(() {
      _strengthValue = v;
      _strengthColor = c;
      _strengthLabel = label;
    });
  }

  // -------------------------------------------
  // REGISTER HANDLER
  // -------------------------------------------
  Future<void> _daftarUser() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _emailErrorText = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final nama = _namaController.text.trim();

      // Daftar lewat AuthService
      await AuthService.instance.register(
        name: nama,
        email: email,
        password: password,
      );

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
            backgroundColor: const Color(0xFF2E7D32), // hijau sukses
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Akun berhasil dibuat! Silakan login.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );

      // Langsung ke halaman login, hapus semua route sebelumnya
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Masuk()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String? emailError;
      String? snackMessage;

      switch (e.code) {
        case 'email-already-in-use':
          emailError = 'Email sudah digunakan.';
          break;
        case 'invalid-email':
          emailError = 'Format email tidak valid.';
          break;
        case 'weak-password':
          snackMessage = 'Kata sandi terlalu lemah.';
          break;
        case 'network-request-failed':
          emailError = 'Tidak dapat terhubung ke jaringan.';
          break;
        default:
          emailError = e.message ?? 'Terjadi kesalahan.';
      }

      setState(() {
        _emailErrorText = emailError;
      });

      if (snackMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(snackMessage)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // -------------------------------------------
  // WIDGET STRENGTH BAR
  // -------------------------------------------

  Widget _strengthBar() {
    final value = _strengthValue;
    final color = _strengthColor;
    final label = _strengthLabel;

    final bool show =
        _passwordFocusNode.hasFocus && _passwordController.text.isNotEmpty;

    if (!show) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 10.h),
        Text(
          "Gunakan kombinasi huruf besar, angka, dan simbol.",
          style: TextStyle(color: Colors.black54, fontSize: 12.sp),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            _Segment(index: 0, activeValue: value, activeColor: color),
            SizedBox(width: 6.w),
            _Segment(index: 1, activeValue: value, activeColor: color),
            SizedBox(width: 6.w),
            _Segment(index: 2, activeValue: value, activeColor: color),
          ],
        ),
        SizedBox(height: 8.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
    String? error,
  }) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      errorText: error,
    );
  }

  // -------------------------------------------
  // BUILD UI
  // -------------------------------------------
  @override
  Widget build(BuildContext context) {
    final bool isPasswordMatch =
        _konfirmasiController.text.trim() == _passwordController.text.trim();

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
                    padding: EdgeInsets.only(
                      left: 28.w,
                      right: 28.w,
                      top: 25.h,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          SizedBox(height: 0.05.sh),

                          FadeTransition(
                            opacity: _fadeAnim,
                            child: SlideTransition(
                              position: _slideAnim,
                              child: Image.asset(
                                'assets/logo.png',
                                width: 90.w,
                                height: 90.w,
                              ),
                            ),
                          ),
                          SizedBox(height: 25.h),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Buat Akun\nBaru Sekarang",
                              style: TextStyle(
                                fontSize: 28.sp,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                          ),
                          SizedBox(height: 25.h),

                          TextFormField(
                            controller: _namaController,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            decoration: _inputDecoration(
                              label: "Nama Lengkap",
                              icon: Icons.person_outline,
                            ),
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) return 'Nama wajib diisi';
                              if (t.length < 3) return 'Nama terlalu pendek';
                              return null;
                            },
                          ),
                          SizedBox(height: 16.h),

                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            decoration: _inputDecoration(
                              label: "Email",
                              icon: Icons.email_outlined,
                              error: _emailErrorText,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Email wajib diisi';
                              }
                              if (!_isValidEmail(v.trim())) {
                                return 'Email tidak valid';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16.h),

                          TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            obscureText: _sembunyikanPassword,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            decoration: _inputDecoration(
                              label: "Kata Sandi",
                              icon: Icons.lock_outline,
                              suffix: IconButton(
                                icon: Icon(
                                  _sembunyikanPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _sembunyikanPassword =
                                        !_sembunyikanPassword;
                                  });
                                },
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Kata sandi wajib diisi';
                              }
                              return null;
                            },
                          ),

                          _strengthBar(),
                          SizedBox(height: 16.h),

                          TextFormField(
                            controller: _konfirmasiController,
                            obscureText: _sembunyikanKonfirmasi,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            decoration: _inputDecoration(
                              label: "Konfirmasi Kata Sandi",
                              icon: Icons.lock_person_outlined,
                              suffix: IconButton(
                                icon: Icon(
                                  _sembunyikanKonfirmasi
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _sembunyikanKonfirmasi =
                                        !_sembunyikanKonfirmasi;
                                  });
                                },
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Konfirmasi wajib diisi';
                              }
                              if (!isPasswordMatch) {
                                return 'Konfirmasi tidak cocok';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 25.h),

                          SizedBox(
                            width: double.infinity,
                            height: 48.h,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _daftarUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDB0C0C),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      "Daftar Sekarang",
                                      style: TextStyle(color: Colors.white),
                                    ),
                            ),
                          ),
                          SizedBox(height: 25.h),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Sudah punya akun? ",
                                style: TextStyle(fontSize: 14.sp),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Text(
                                  "Masuk di sini",
                                  style: TextStyle(
                                    color: Color(0xFFDB0C0C),
                                    fontWeight: FontWeight.bold,
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
      ),
    );
  }
}

// -------------------------------------------
// SEGMENT WIDGET
// -------------------------------------------

class _Segment extends StatelessWidget {
  final int index;
  final double activeValue;
  final Color activeColor;

  const _Segment({
    required this.index,
    required this.activeValue,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool active =
        (activeValue >= 1.0 && index <= 2) ||
        (activeValue >= 0.5 && activeValue < 1.0 && index <= 1) ||
        (activeValue >= 0.25 && activeValue < 0.5 && index == 0);

    final Color color = active ? activeColor : Colors.grey.shade300;

    return Expanded(
      child: Container(
        height: 8.h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
    );
  }
}
