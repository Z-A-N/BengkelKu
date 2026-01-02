// lib/features/booking/booking_success.dart
// ignore_for_file: deprecated_member_use, unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:confetti/confetti.dart';

import '../../models/bengkel_model.dart';
import 'booking_summary.dart'; // ✅ biar LayananItem kebaca
import 'booking_code_page.dart';

class BookingSuccessPage extends StatefulWidget {
  final String bookingId;
  final Bengkel bengkel;
  final List<LayananItem> layananDipilih;
  final DateTime tanggal;
  final String jam;
  final String jenisKendaraan;
  final String nomorPolisi;
  final String catatan;
  final String metodePembayaran;

  final String vehicleLabel;
  final String vehicleTahun;
  final String vehicleKm;

  const BookingSuccessPage({
    super.key,
    required this.bookingId,
    required this.bengkel,
    required this.layananDipilih,
    required this.tanggal,
    required this.jam,
    required this.jenisKendaraan,
    required this.nomorPolisi,
    required this.catatan,
    required this.metodePembayaran,
    this.vehicleLabel = '',
    this.vehicleTahun = '',
    this.vehicleKm = '',
  });

  @override
  State<BookingSuccessPage> createState() => _BookingSuccessPageState();
}

class _BookingSuccessPageState extends State<BookingSuccessPage>
    with TickerProviderStateMixin {
  late final ConfettiController _confetti;

  // animasi success group (center)
  late final AnimationController _appear;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _liftY; // ✅ naik dikit

  // animasi sheet masuk (delay)
  late final AnimationController _sheetEnter;
  late final Animation<Offset> _sheetOffset;
  late final Animation<double> _sheetOpacity;

  double _sheetExtent = 0.32; // ✅ start lebih bawah

  @override
  void initState() {
    super.initState();

    // ✅ confetti nonstop (durasi panjang + shouldLoop true)
    _confetti = ConfettiController(duration: const Duration(hours: 6));

    _appear = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _scale = Tween<double>(
      begin: 0.75,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _appear, curve: Curves.elasticOut));

    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _appear, curve: Curves.easeOut));

    // ✅ lift halus (dari bawah dikit -> naik dikit)
    _liftY = Tween<double>(
      begin: 14.h,
      end: -8.h,
    ).animate(CurvedAnimation(parent: _appear, curve: Curves.easeOutCubic));

    _sheetEnter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _sheetOffset = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _sheetEnter, curve: Curves.easeOutCubic));

    _sheetOpacity = CurvedAnimation(parent: _sheetEnter, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      _confetti.play();
      _appear.forward(); // ✅ animasi sukses dulu

      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      _sheetEnter.forward();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    _appear.dispose();
    _sheetEnter.dispose();
    super.dispose();
  }

  void _backToDetailReset() {
    Navigator.pop(context, true);
  }

  void _goToBookingCode() {
    final label = (widget.vehicleLabel.trim().isNotEmpty)
        ? widget.vehicleLabel.trim()
        : [
            widget.jenisKendaraan.trim(),
            widget.nomorPolisi.trim(),
          ].where((e) => e.isNotEmpty).join(" • ");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingCodePage(
          bookingId: widget.bookingId,
          bengkelNama: widget.bengkel.nama,
          tanggal: widget.tanggal,
          jam: widget.jam,
          vehicleLabel: label.isEmpty ? "-" : label,
          nomorPolisi: widget.nomorPolisi.trim(),
          showBackToHomeButton: true,
        ),
      ),
    );
  }

  // ✅ helper aman: int/double/String/null -> num
  num _asNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    // ✅ total aman
    final total = widget.layananDipilih
        .fold<num>(0, (p, e) => p + _asNum(e.harga))
        .toInt();

    final isFull = _sheetExtent >= 0.98;

    // ✅ success group makin hilang saat sheet ditarik mendekati full (biar clean)
    final groupFade = (1 - ((_sheetExtent - 0.70) / 0.30)).clamp(0.0, 1.0);

    return WillPopScope(
      onWillPop: () async {
        _backToDetailReset();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFF3366),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              Container(color: const Color(0xFFFF3366)),

              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: true, // ✅ nonstop
                  numberOfParticles: 22,
                  maxBlastForce: 20,
                  minBlastForce: 8,
                  emissionFrequency: 0.02, // ✅ lebih rame sedikit
                ),
              ),

              // ✅ sukses di tengah, naik sedikit
              Center(
                child: Opacity(
                  opacity: groupFade,
                  child: FadeTransition(
                    opacity: _opacity,
                    child: AnimatedBuilder(
                      animation: _liftY,
                      builder: (_, child) {
                        return Transform.translate(
                          offset: Offset(0, _liftY.value),
                          child: child,
                        );
                      },
                      child: ScaleTransition(
                        scale: _scale,
                        child: _buildSuccessGroup(),
                      ),
                    ),
                  ),
                ),
              ),

              // ✅ sheet muncul setelah delay, masuk dari bawah
              AnimatedBuilder(
                animation: _sheetEnter,
                builder: (_, child) {
                  return IgnorePointer(
                    ignoring: _sheetEnter.status != AnimationStatus.completed,
                    child: child,
                  );
                },
                child: FadeTransition(
                  opacity: _sheetOpacity,
                  child: SlideTransition(
                    position: _sheetOffset,
                    child:
                        NotificationListener<DraggableScrollableNotification>(
                          onNotification: (n) {
                            if ((_sheetExtent - n.extent).abs() > 0.002) {
                              setState(() => _sheetExtent = n.extent);
                            }
                            return false;
                          },
                          child: DraggableScrollableSheet(
                            initialChildSize: 0.32, // ✅ lebih bawah
                            minChildSize: 0.18, // ✅ bisa ditarik makin bawah
                            maxChildSize: 1.0, // ✅ full nutup merah
                            builder: (ctx, scrollController) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(isFull ? 0 : 28.r),
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _buildSheet(
                                  context: ctx,
                                  total: total,
                                  scrollController: scrollController,
                                  isFull: isFull,
                                  topSafe: mq.padding.top,
                                  bottomSafe: mq.padding.bottom,
                                ),
                              );
                            },
                          ),
                        ),
                  ),
                ),
              ),

              // ✅ tombol close tetap di atas semuanya
              Positioned(
                top: mq.padding.top + 8.h,
                left: 10.w,
                child: Material(
                  color: Colors.white,
                  elevation: 2,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _backToDetailReset,
                    child: Padding(
                      padding: EdgeInsets.all(8.w),
                      child: Icon(
                        Icons.close,
                        size: 20.sp,
                        color: Colors.black87,
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

  Widget _buildSuccessGroup() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 92.w,
            height: 92.w,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.green,
              size: 54,
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            "Booking Berhasil!",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6.h),
          Text(
            "Pesanan kamu sudah diterima oleh bengkel.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: 12.sp,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(22.r),
            ),
            child: Text(
              "Booking ID: ${widget.bookingId}",
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheet({
    required BuildContext context,
    required int total,
    required ScrollController scrollController,
    required bool isFull,
    required double topSafe,
    required double bottomSafe,
  }) {
    final topPad = isFull ? (topSafe + 12.h) : 14.h;

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(16.w, topPad, 16.w, 22.h + bottomSafe),
      children: [
        Center(
          child: Container(
            width: 46.w,
            height: 5.h,
            margin: EdgeInsets.only(bottom: 14.h),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),

        if (isFull)
          Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: Text(
              "Ringkasan Booking",
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900),
            ),
          ),

        _buildBengkelCard(),
        SizedBox(height: 16.h),
        _buildTanggalWaktuSection(),
        SizedBox(height: 16.h),
        _buildLayananSection(total),
        SizedBox(height: 16.h),
        _buildStatusSection(),
        SizedBox(height: 16.h),
        _buildInfoKendaraanSection(),
        SizedBox(height: 16.h),
        _buildMetodePembayaranSection(),
        SizedBox(height: 22.h),

        SizedBox(
          width: double.infinity,
          height: 46.h,
          child: ElevatedButton(
            onPressed: _goToBookingCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD740),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.r),
              ),
            ),
            child: Text(
              "Lihat Kode Booking",
              style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBengkelCard() {
    final fotoUrl = widget.bengkel.foto.trim();
    final hasUrl = fotoUrl.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: SizedBox(
              width: 64.w,
              height: 64.w,
              child: hasUrl
                  ? Image.network(
                      fotoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.car_repair, color: Colors.grey),
                      ),
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.car_repair, color: Colors.grey),
                    ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.bengkel.nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Colors.grey,
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        widget.bengkel.alamat,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTanggalWaktuSection() {
    final tanggalStr =
        "${widget.tanggal.day} ${_namaBulan(widget.tanggal.month)} ${widget.tanggal.year}";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Tanggal & Waktu Booking"),
        SizedBox(height: 8.h),
        _iconRow(
          icon: Icons.calendar_today_outlined,
          label: "Tanggal",
          value: tanggalStr,
        ),
        SizedBox(height: 10.h),
        _iconRow(icon: Icons.access_time, label: "Waktu", value: widget.jam),
      ],
    );
  }

  Widget _iconRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 32.w,
          height: 32.w,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3CD),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFFFF9800)),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[700]),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLayananSection(int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Layanan Dipilih"),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              for (final l in widget.layananDipilih) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(l.nama, style: TextStyle(fontSize: 13.sp)),
                    ),
                    Text(
                      "Rp ${_asNum(l.harga).toInt()}",
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (l != widget.layananDipilih.last)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 6.h),
                    child: Divider(height: 1, color: Colors.grey.shade200),
                  ),
              ],
              SizedBox(height: 10.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Total Biaya",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    "Rp $total",
                    style: const TextStyle(
                      color: Color(0xFFDB0C0C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Status Booking"),
        SizedBox(height: 8.h),
        _statusRow(
          icon: Icons.check_circle,
          color: const Color(0xFF4CAF50),
          title: "Booking Diterima",
          time: "Baru saja",
          isDone: true,
        ),
        _statusRow(
          icon: Icons.timelapse,
          color: const Color(0xFFFFC107),
          title: "Proses",
          time: "Menunggu konfirmasi bengkel",
          isDone: false,
        ),
      ],
    );
  }

  Widget _statusRow({
    required IconData icon,
    required Color color,
    required String title,
    required String time,
    required bool isDone,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  time,
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoKendaraanSection() {
    final fallbackLabel = [
      widget.jenisKendaraan.trim(),
      widget.nomorPolisi.trim(),
    ].where((e) => e.isNotEmpty).join(" • ");

    final label = widget.vehicleLabel.trim().isNotEmpty
        ? widget.vehicleLabel.trim()
        : (fallbackLabel.isEmpty ? "-" : fallbackLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Informasi Kendaraan"),
        SizedBox(height: 8.h),
        _infoRow("Kendaraan", label),
        if (widget.nomorPolisi.trim().isNotEmpty)
          _infoRow("Nomor Polisi", widget.nomorPolisi.trim()),
        if (widget.vehicleKm.trim().isNotEmpty)
          _infoRow("KM", widget.vehicleKm.trim()),
        _infoRow("Catatan", widget.catatan.isEmpty ? "-" : widget.catatan),
      ],
    );
  }

  Widget _buildMetodePembayaranSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Metode Pembayaran"),
        SizedBox(height: 8.h),
        _infoRow("Metode", widget.metodePembayaran),
        _infoRow("Status Pembayaran", "Belum dibayar"),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
    );
  }

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
}
