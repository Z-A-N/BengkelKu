import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../onboarding/onboarding_screen.dart';
import '../auth/screens/vehicle_form_screen.dart';
import '../home/home_dashboard.dart';
import '../auth/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  Timer? _navTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/logo.png'), context);
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();

    _navTimer = Timer(const Duration(seconds: 3), () async {
      if (!mounted) return;

      final dest = await AuthService.instance.resolveStartDestination();
      if (!mounted) return;

      final page = switch (dest) {
        AuthStartDestination.onboarding => const OnboardingScreen(),
        AuthStartDestination.vehicleForm => const VehicleFormScreen(),
        AuthStartDestination.home => const HomeDashboard(),
      };

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Shader _linearGradient(List<Color> colors) {
    return LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🎞️ Logo animasi
            ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Image.asset(
                  'assets/logo.png',
                  width: 120.w,
                  height: 120.w,
                ),
              ),
            ),
            SizedBox(height: 20.h),

            // Teks BengkelKu
            FadeTransition(
              opacity: _fadeAnimation,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // BENGKEL
                  Stack(
                    children: [
                      Text(
                        'Bengkel',
                        style: TextStyle(
                          fontSize: 34.sp,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Poppins',
                          letterSpacing: 1.2,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 3.w
                            ..color = const Color.fromARGB(246, 248, 203, 25),
                        ),
                      ),
                      Text(
                        'Bengkel',
                        style: TextStyle(
                          fontSize: 34.sp,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Poppins',
                          letterSpacing: 1.2,
                          foreground: Paint()
                            ..shader = _linearGradient([
                              const Color.fromARGB(255, 231, 56, 88),
                              const Color(0xFFE21B4D),
                              const Color(0xFFC0103A),
                            ]),
                          shadows: [
                            Shadow(
                              offset: Offset(1.w, 2.h),
                              blurRadius: 3.w,
                              color: const Color(0x33000000),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // KU.
                  Stack(
                    children: [
                      Text(
                        'Ku.',
                        style: TextStyle(
                          fontSize: 34.sp,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Poppins',
                          letterSpacing: 1.2,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 3.w
                            ..color = const Color(0xFFB01D1D),
                        ),
                      ),
                      Text(
                        'Ku.',
                        style: TextStyle(
                          fontSize: 34.sp,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Poppins',
                          letterSpacing: 1.2,
                          foreground: Paint()
                            ..shader = _linearGradient([
                              const Color(0xFFFFF799),
                              const Color(0xFFFFD320),
                              const Color(0xFFF9B700),
                            ]),
                          shadows: [
                            Shadow(
                              offset: Offset(1.w, 2.h),
                              blurRadius: 3.w,
                              color: const Color(0x33000000),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
