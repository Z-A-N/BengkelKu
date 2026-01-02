// lib/screen/booking/booking_code_page.dart
// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BookingCodePage extends StatelessWidget {
  final String bookingId;
  final String bengkelNama;
  final DateTime tanggal;
  final String jam;

  final String vehicleLabel;
  final String nomorPolisi;

  final bool showBackToHomeButton; // ✅ NEW

  const BookingCodePage({
    super.key,
    required this.bookingId,
    required this.bengkelNama,
    required this.tanggal,
    required this.jam,
    required this.vehicleLabel,
    required this.nomorPolisi,
    this.showBackToHomeButton = true,
  });

  String _namaBulan(int m) {
    const list = [
      "",
      "Januari",
      "Februari",
      "Maret",
      "April",
      "Mei",
      "Juni",
      "Juli",
      "Agustus",
      "September",
      "Oktober",
      "November",
      "Desember",
    ];
    return list[m];
  }

  String _fmtTanggal(DateTime d) {
    return "${d.day} ${_namaBulan(d.month)} ${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    final code = bookingId.trim().isEmpty ? "-" : bookingId.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFD740),
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text(
          "Kode Booking",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 18.h),
          children: [
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Tunjukkan kode ini ke bengkel saat datang.",
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 12.h),
                  _FakeBarcode(value: code),
                  SizedBox(height: 12.h),
                  Center(
                    child: SelectableText(
                      code,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  SizedBox(
                    width: double.infinity,
                    height: 42.h,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Kode booking disalin"),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text("Salin Kode"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            _InfoCard(
              title: "Detail Booking",
              children: [
                _kv("Bengkel", bengkelNama),
                _kv("Tanggal", _fmtTanggal(tanggal)),
                _kv("Jam", jam),
                _kv("Kendaraan", vehicleLabel),
                if (nomorPolisi.trim().isNotEmpty)
                  _kv("Nomor Polisi", nomorPolisi),
              ],
            ),
            SizedBox(height: 14.h),

            // ✅ HANYA tampil kalau dari booking_success
            if (showBackToHomeButton)
              SizedBox(
                width: double.infinity,
                height: 46.h,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32), // ✅ ganti warna
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                  ),
                  child: Text(
                    "Kembali ke Beranda",
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    final vv = v.trim().isEmpty ? "-" : v.trim();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96.w,
            child: Text(
              k,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            child: Text(
              vv,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFFFE082)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 10.h),
          ...children,
        ],
      ),
    );
  }
}

class _FakeBarcode extends StatelessWidget {
  final String value;
  const _FakeBarcode({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90.h,
      width: double.infinity,
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: CustomPaint(
        painter: _BarcodePainter(value),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  final String value;
  _BarcodePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black87;

    int seed = 0;
    for (final r in value.codeUnits) {
      seed = (seed * 31 + r) & 0x7fffffff;
    }
    final rand = Random(seed);

    double x = 0;
    final maxH = size.height;
    while (x < size.width) {
      final w = rand.nextInt(3) + 1;
      final gap = rand.nextInt(3) + 1;
      final h = maxH * (0.65 + rand.nextDouble() * 0.35);
      final rect = Rect.fromLTWH(x, (maxH - h) / 2, w.toDouble(), h);
      canvas.drawRect(rect, paint);
      x += w + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodePainter oldDelegate) {
    return oldDelegate.value != value;
  }
}
