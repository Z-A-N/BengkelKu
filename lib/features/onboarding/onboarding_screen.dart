// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../auth/screens/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _controller;
  int _currentPage = 0;

  Timer? _autoSlideTimer;
  bool _isAnimating = false;
  bool _userDragging = false;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  bool _didPrecache = false;

  // ✅ biar request izin ga keulang-ulang
  bool _permissionRequestedOnce = false;

  static const List<Map<String, String>> onboardingData = [
    {
      "image": "assets/board1.png",
      "title": "Temukan Bengkel Terdekat",
      "desc": "Lihat bengkel di sekitar kamu dengan mudah dan cepat.",
    },
    {
      "image": "assets/board2.png",
      "title": "Booking Layanan dari Rumah",
      "desc": "Pesan perbaikan kendaraan tanpa perlu datang ke bengkel.",
    },
    {
      "image": "assets/board3.png",
      "title": "Panggil Teknisi Darurat",
      "desc": "Teknisi siap datang ke lokasi kamu kapan pun dibutuhkan.",
    },
  ];

  static const _autoSlideEvery = Duration(seconds: 4);
  static const _slideDuration = Duration(milliseconds: 600);
  static const _slideCurve = Curves.easeInOut;

  bool get _isLastPage => _currentPage == onboardingData.length - 1;

  @override
  void initState() {
    super.initState();

    _controller = PageController();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _startAutoSlide();

    // ✅ langsung munculin dialog izin dari OS (tanpa popup custom)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissionsOnce();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_didPrecache) {
      _didPrecache = true;
      for (final item in onboardingData) {
        final path = item["image"];
        if (path != null) {
          precacheImage(AssetImage(path), context);
        }
      }
    }
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(_autoSlideEvery, (_) {
      _autoSlideTick();
    });
  }

  Future<void> _autoSlideTick() async {
    if (!mounted) return;
    if (!_controller.hasClients || _isAnimating || _userDragging) return;

    _isAnimating = true;
    try {
      final nextPage = _currentPage + 1;

      // auto balik ke awal kalau udah last page
      if (nextPage >= onboardingData.length) {
        await _fadeController.forward();
        if (!mounted) return;

        await _controller.animateToPage(
          0,
          duration: _slideDuration,
          curve: _slideCurve,
        );
        if (!mounted) return;

        await _fadeController.reverse();
      } else {
        await _controller.animateToPage(
          nextPage,
          duration: _slideDuration,
          curve: _slideCurve,
        );
      }
    } catch (_) {
      // aman
    } finally {
      _isAnimating = false;
    }
  }

  void _stopAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = null;
  }

  @override
  void dispose() {
    _stopAutoSlide();
    _controller.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // =========================
  // PERMISSIONS (NO CUSTOM UI, NO SNACKBAR)
  // =========================

  Future<void> _requestPermissionsOnce() async {
    if (_permissionRequestedOnce) return;
    _permissionRequestedOnce = true;

    await _requestNotificationPermission();
    await _requestLocationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    // Android 13+ / iOS
    final status = await Permission.notification.status;

    // kalau sudah granted / permanently denied, jangan ganggu
    if (status.isGranted || status.isPermanentlyDenied) return;

    await Permission.notification.request();
  }

  Future<void> _requestLocationPermission() async {
    // kalau GPS mati, kita ga buka settings otomatis (biar ga ada popup tambahan)
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var perm = await Geolocator.checkPermission();

    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission(); // ini native dialog OS
    }

    // deniedForever -> jangan paksa buka settings (sesuai request kamu)
  }

  // =========================
  // NAV
  // =========================

  void _navigateToLogin() {
    _stopAutoSlide();
    if (!mounted) return;

    // optional: pastiin pernah minta izin (kalau user skip cepat)
    _requestPermissionsOnce();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const Masuk()),
    );
  }

  Future<void> _goToLastSlideWithFade() async {
    if (_isAnimating) return;

    _stopAutoSlide();
    _isAnimating = true;

    try {
      await _fadeController.forward();
      if (!mounted) return;

      await _controller.animateToPage(
        onboardingData.length - 1,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
      if (!mounted) return;

      await _fadeController.reverse();
    } catch (_) {
      // aman
    } finally {
      _isAnimating = false;
      _startAutoSlide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final isSmall = height < 700;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            const BottomHalfCircleOrnament(),

            FadeTransition(
              opacity: _fadeAnimation.drive(
                Tween<double>(begin: 1.0, end: 0.6),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: NotificationListener<UserScrollNotification>(
                      onNotification: (notification) {
                        final dir = notification.direction;

                        if (dir != ScrollDirection.idle && !_userDragging) {
                          _userDragging = true;
                          _stopAutoSlide();
                        } else if (dir == ScrollDirection.idle &&
                            _userDragging) {
                          _userDragging = false;
                          _startAutoSlide();
                        }
                        return false;
                      },
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: onboardingData.length,
                        onPageChanged: (index) {
                          if (!mounted) return;
                          setState(() => _currentPage = index);
                        },
                        itemBuilder: (context, index) {
                          final item = onboardingData[index];
                          final isLastSlide =
                              index == onboardingData.length - 1;

                          final double topPadding = isSmall
                              ? (isLastSlide ? 95.h : 115.h)
                              : (isLastSlide ? 115.h : 135.h);

                          final double imageHeight = isSmall
                              ? (isLastSlide ? 170.h : 145.h)
                              : (isLastSlide ? 200.h : 170.h);

                          return Padding(
                            padding: EdgeInsets.only(top: topPadding),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Image.asset(
                                  item["image"]!,
                                  height: imageHeight,
                                  fit: BoxFit.contain,
                                ),
                                SizedBox(height: 35.h),
                                Text(
                                  item["title"]!,
                                  style: TextStyle(
                                    fontSize: 22.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFB01D1D),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 12.h),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 30.w,
                                  ),
                                  child: Text(
                                    item["desc"]!,
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      color: Colors.black54,
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  if (!_isLastPage) ...[
                    Padding(
                      padding: EdgeInsets.only(bottom: 15.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          onboardingData.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: EdgeInsets.symmetric(horizontal: 4.w),
                            width: _currentPage == index ? 14.w : 8.w,
                            height: 8.h,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? const Color(0xFFE40A0A)
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 25.h),
                  ],

                  if (_isLastPage)
                    Padding(
                      padding: EdgeInsets.fromLTRB(80.w, 0, 80.w, 45.h),
                      child: ElevatedButton(
                        onPressed: _navigateToLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDB0C0C),
                          minimumSize: Size(double.infinity, 50.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          elevation: 4,
                        ),
                        child: Text(
                          "Mulai Sekarang",
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                  SizedBox(height: 15.h),
                ],
              ),
            ),

            if (!_isLastPage)
              Positioned(
                right: 20.w,
                top: 10.h,
                child: TextButton(
                  onPressed: _goToLastSlideWithFade,
                  child: Text(
                    "Lewati",
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Ornamen bawah (gradasi kuning)
class BottomHalfCircleOrnament extends StatelessWidget {
  const BottomHalfCircleOrnament({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final double diameter = size.width * 1.6;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: double.infinity,
        height: size.height * 0.4,
        child: CustomPaint(painter: _SunrisePainter(diameter)),
      ),
    );
  }
}

class _SunrisePainter extends CustomPainter {
  final double diameter;

  _SunrisePainter(this.diameter);

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height);
    final Rect rect = Rect.fromCircle(center: center, radius: diameter / 2);

    final Paint paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFF59D),
          const Color(0xFFFFEE58),
          const Color.fromARGB(60, 255, 214, 64),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 0.3, 0.6, 1.0],
        center: Alignment.bottomCenter,
        radius: 1.0,
      ).createShader(rect);

    canvas.drawCircle(center, diameter / 2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
