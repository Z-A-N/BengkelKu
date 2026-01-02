// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OrnamenSetengahLingkaranAtas extends StatelessWidget {
  const OrnamenSetengahLingkaranAtas({super.key});

  @override
  Widget build(BuildContext context) {
    final double diameter = 1.6.sw;

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: double.infinity,
        height: 0.3.sh,
        child: CustomPaint(
          painter: _LukisMatahariTerbit(diameter),
        ),
      ),
    );
  }
}

class _LukisMatahariTerbit extends CustomPainter {
  final double diameter;
  const _LukisMatahariTerbit(this.diameter);

  @override
  void paint(Canvas canvas, Size size) {
    final Offset tengah = Offset(size.width / 2, 0);
    final Rect area = Rect.fromCircle(center: tengah, radius: diameter / 2);

    final Paint kuas = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFFFFF59D),
          Color(0xFFFFEE58),
          Color.fromARGB(60, 255, 214, 64),
          Colors.transparent,
        ],
        stops: [0.0, 0.3, 0.6, 1.0],
        center: Alignment.topCenter,
        radius: 1.0,
      ).createShader(area);

    canvas.drawCircle(tengah, diameter / 2, kuas);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
