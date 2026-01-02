// riwayat_detail.dart
// ignore_for_file: deprecated_member_use, unnecessary_underscores, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../booking/booking_code_page.dart';
import '../../features/ulasan/ulasan_sheet.dart';

class RiwayatDetailPage extends StatefulWidget {
  final String bookingId;

  const RiwayatDetailPage({super.key, required this.bookingId});

  @override
  State<RiwayatDetailPage> createState() => _RiwayatDetailPageState();
}

class _RiwayatDetailPageState extends State<RiwayatDetailPage> {
  bool _isCancelling = false;

  DateTime _toDate(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  num _asNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString().replaceAll(RegExp(r'[^0-9\.-]'), '')) ?? 0;
  }

  String _fmtDate(DateTime dt) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "Mei",
      "Jun",
      "Jul",
      "Agu",
      "Sep",
      "Okt",
      "Nov",
      "Des",
    ];
    final d = dt.day;
    final m = months[(dt.month - 1).clamp(0, 11)];
    final y = dt.year;
    return "$d $m $y";
  }

  String _rupiah(num v) {
    final n = v.toInt();
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write('.');
    }
    return "Rp ${buf.toString()}";
  }

  String _norm(String s) => s.toLowerCase().trim();

  // ✅ lebih kebal: status bisa "selesai ✅", "menunggu konfirmasi", dll
  bool _isMenunggu(String s) {
    s = _norm(s);
    return s.contains("menunggu") ||
        s.contains("pending") ||
        s.contains("waiting");
  }

  bool _isProses(String s) {
    s = _norm(s);
    return s.contains("proses") ||
        s.contains("diproses") ||
        s.contains("process");
  }

  bool _isSelesai(String s) {
    s = _norm(s);
    return s.contains("selesai") || s.contains("done") || s.contains("finish");
  }

  bool _isBatal(String s) {
    s = _norm(s);
    return s.contains("batal") ||
        s.contains("cancelled") ||
        s.contains("canceled");
  }

  String _statusLabel(String s) {
    s = _norm(s);
    if (_isMenunggu(s)) return "Menunggu";
    if (_isProses(s)) return "Proses";
    if (_isSelesai(s)) return "Selesai";
    if (_isBatal(s)) return "Batal";
    return s.isEmpty ? "-" : s;
  }

  Color _statusBg(String s) {
    s = _norm(s);
    if (_isSelesai(s)) return const Color(0xFFE8F5E9);
    if (_isBatal(s)) return const Color(0xFFFFEBEE);
    if (_isProses(s)) return const Color(0xFFFFF8E1);
    return const Color(0xFFFFF3CD);
  }

  Color _statusTextColor(String s) {
    s = _norm(s);
    if (_isSelesai(s)) return const Color(0xFF2E7D32);
    if (_isBatal(s)) return const Color(0xFFEB5757);
    return const Color(0xFFF2994A);
  }

  String _vehicleLabelFromBooking(Map<String, dynamic> data) {
    final jenis = (data["jenisKendaraan"] ?? "").toString().trim();
    final merek = (data["vehicleMerek"] ?? "").toString().trim();
    final model = (data["vehicleModel"] ?? "").toString().trim();
    final tahun = (data["vehicleTahun"] ?? data["tahun"] ?? "")
        .toString()
        .trim();

    final brandModel = [
      merek,
      model,
    ].where((e) => e.isNotEmpty).join(" ").trim();

    final parts = <String>[];
    if (jenis.isNotEmpty) parts.add(jenis);
    if (brandModel.isNotEmpty) parts.add(brandModel);
    if (tahun.isNotEmpty) parts.add(tahun);

    if (parts.isNotEmpty) return parts.join(" • ");
    final direct = (data["vehicleLabel"] ?? "").toString().trim();
    return direct.isNotEmpty ? direct : "-";
  }

  IconData _vehicleIcon(String labelOrJenis) {
    final s = labelOrJenis.toLowerCase();
    if (s.contains("motor") || s.contains("sepeda")) return Icons.two_wheeler;
    if (s.contains("mobil") || s.contains("car")) return Icons.directions_car;
    return Icons.directions;
  }

  Future<void> _cancelBooking({
    required String bookingId,
    required String statusRaw,
  }) async {
    if (_isCancelling) return;
    if (!_isMenunggu(statusRaw)) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Batalkan Booking?"),
        content: const Text(
          "Booking akan dibatalkan. Kamu bisa booking ulang nanti.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Tidak"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Ya, Batalkan"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _isCancelling = true);
    try {
      await FirebaseFirestore.instance
          .collection("bookings")
          .doc(bookingId)
          .update({
            "status": "batal",
            "cancelledAt": FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Booking berhasil dibatalkan"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal membatalkan booking.\n$e"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  void _goToCodePage({
    required String bookingCode,
    required String bengkelNama,
    required DateTime tanggal,
    required String jam,
    required String vehicleLabel,
    required String nomorPolisi,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingCodePage(
          bookingId: bookingCode,
          bengkelNama: bengkelNama,
          tanggal: tanggal,
          jam: jam,
          vehicleLabel: vehicleLabel,
          nomorPolisi: nomorPolisi,
          showBackToHomeButton: false,
        ),
      ),
    );
  }

  void _finishToHome() {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _finishWithReviewFlow({
    required bool reviewed,
    required String bookingId,
    required String bengkelId,
    required String bengkelNama,
  }) async {
    if (reviewed) {
      _finishToHome();
      return;
    }

    final submitted = await showUlasanSheet(
      context: context,
      bookingId: bookingId,
      bengkelId: bengkelId,
      bengkelNama: bengkelNama,
    );

    if (submitted) _finishToHome();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              title: "Detail Pesanan",
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: (user == null)
                  ? Center(
                      child: Text(
                        "Silakan login untuk melihat detail.",
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.grey[700],
                        ),
                      ),
                    )
                  : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection("bookings")
                          .doc(widget.bookingId)
                          .snapshots(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snap.hasError) {
                          return Center(
                            child: Text(
                              "Gagal memuat detail.\n${snap.error}",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[700],
                              ),
                            ),
                          );
                        }

                        final data = snap.data?.data();
                        if (data == null) {
                          return Center(
                            child: Text(
                              "Data booking tidak ditemukan.",
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.grey[700],
                              ),
                            ),
                          );
                        }

                        final ownerId = (data["userId"] ?? "").toString();
                        if (ownerId.isNotEmpty && ownerId != user.uid) {
                          return Center(
                            child: Text(
                              "Kamu tidak punya akses ke booking ini.",
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.grey[700],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        final bengkelId = (data["bengkelId"] ?? "")
                            .toString()
                            .trim();
                        final bengkelNama = (data["bengkelNama"] ?? "Bengkel")
                            .toString();
                        final bengkelAlamat = (data["bengkelAlamat"] ?? "-")
                            .toString();
                        final bengkelFoto = (data["bengkelFoto"] ?? "")
                            .toString();

                        final tanggal = _toDate(data["tanggal"]);
                        final jam = (data["jam"] ?? "-").toString();

                        final metode = (data["metodePembayaran"] ?? "-")
                            .toString();
                        final catatan = (data["catatan"] ?? "").toString();

                        final statusRaw = (data["status"] ?? "").toString();
                        final status = _statusLabel(statusRaw);

                        final vehicleLabel = _vehicleLabelFromBooking(data);
                        final nomorPolisi = (data["nomorPolisi"] ?? "")
                            .toString()
                            .trim();
                        final vehicleKm = (data["vehicleKm"] ?? "")
                            .toString()
                            .trim();

                        final bookingCode =
                            (data["bookingCode"] ??
                                    data["id"] ??
                                    widget.bookingId)
                                .toString()
                                .trim();

                        final layanan = (data["layanan"] is List)
                            ? (data["layanan"] as List)
                            : <dynamic>[];

                        num total = 0;
                        for (final it in layanan) {
                          if (it is Map) total += _asNum(it["harga"]);
                        }

                        final isMenunggu = _isMenunggu(statusRaw);
                        final isProses = _isProses(statusRaw);
                        final isSelesai = _isSelesai(statusRaw);
                        final isBatal = _isBatal(statusRaw);

                        // ✅ reviewed dari booking doc (biar sederhana)
                        // kalau kamu mau lebih “anti reset”, bisa juga cek doc reviews exists (opsional)
                        final reviewed = (data["reviewed"] == true);
                        final reviewLater =
                            (data["reviewLater"] == true) && !reviewed;

                        return Stack(
                          children: [
                            ListView(
                              padding: EdgeInsets.fromLTRB(
                                16.w,
                                16.h,
                                16.w,
                                110.h,
                              ),
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        bengkelNama,
                                        style: TextStyle(
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10.w,
                                        vertical: 5.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statusBg(statusRaw),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w800,
                                          color: _statusTextColor(statusRaw),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10.h),

                                _Card(
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          14.r,
                                        ),
                                        child: _BengkelImage(url: bengkelFoto),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Bengkel",
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              bengkelNama,
                                              style: TextStyle(
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w800,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              bengkelAlamat,
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                color: Colors.grey[700],
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 12.h),

                                _Card(
                                  title: "Jadwal",
                                  child: Column(
                                    children: [
                                      _InfoRow(
                                        icon: Icons.calendar_today_outlined,
                                        label: "Tanggal",
                                        value:
                                            (tanggal.millisecondsSinceEpoch ==
                                                0)
                                            ? "-"
                                            : _fmtDate(tanggal),
                                      ),
                                      SizedBox(height: 8.h),
                                      _InfoRow(
                                        icon: Icons.access_time,
                                        label: "Jam",
                                        value: jam.isEmpty ? "-" : jam,
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 12.h),

                                _Card(
                                  title: "Kendaraan",
                                  child: Column(
                                    children: [
                                      _InfoRow(
                                        icon: _vehicleIcon(vehicleLabel),
                                        label: "Kendaraan",
                                        value: vehicleLabel,
                                      ),
                                      if (nomorPolisi.isNotEmpty) ...[
                                        SizedBox(height: 8.h),
                                        _InfoRow(
                                          icon: Icons
                                              .confirmation_number_outlined,
                                          label: "Nomor Polisi",
                                          value: nomorPolisi,
                                        ),
                                      ],
                                      if (vehicleKm.isNotEmpty) ...[
                                        SizedBox(height: 8.h),
                                        _InfoRow(
                                          icon: Icons.speed_outlined,
                                          label: "KM",
                                          value: vehicleKm,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                SizedBox(height: 12.h),

                                _Card(
                                  title: "Layanan Dipilih",
                                  child: Column(
                                    children: [
                                      if (layanan.isEmpty)
                                        Text(
                                          "-",
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: Colors.grey[700],
                                          ),
                                        )
                                      else
                                        ...layanan.map((it) {
                                          final m = (it is Map)
                                              ? it
                                              : <String, dynamic>{};
                                          final nama = (m["nama"] ?? "-")
                                              .toString();
                                          final harga = _asNum(m["harga"]);
                                          return Padding(
                                            padding: EdgeInsets.only(
                                              bottom: 8.h,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    nama,
                                                    style: TextStyle(
                                                      fontSize: 12.sp,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  _rupiah(harga),
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.w800,
                                                    color: const Color(
                                                      0xFFDB0C0C,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      const Divider(height: 18),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              "Total",
                                              style: TextStyle(
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _rupiah(total),
                                            style: TextStyle(
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.w900,
                                              color: const Color(0xFFDB0C0C),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 12.h),

                                _Card(
                                  title: "Pembayaran & Catatan",
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _InfoRow(
                                        icon: Icons.payments_outlined,
                                        label: "Metode",
                                        value: metode.isEmpty ? "-" : metode,
                                      ),
                                      SizedBox(height: 10.h),
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.all(12.w),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF7F7F7),
                                          borderRadius: BorderRadius.circular(
                                            12.r,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                        child: Text(
                                          catatan.trim().isEmpty
                                              ? "Catatan: -"
                                              : catatan,
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: Colors.grey[800],
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 10.h),

                                if (isMenunggu)
                                  const _HintBanner(
                                    icon: Icons.info_outline,
                                    text:
                                        "Tunjukkan kode booking saat datang ke bengkel untuk verifikasi.",
                                  )
                                else if (isProses)
                                  const _HintBanner(
                                    icon: Icons.timelapse,
                                    text:
                                        "Booking sedang diproses. Tombol selesai aktif setelah bengkel menandai selesai.",
                                  )
                                else if (reviewed)
                                  const _HintBanner(
                                    icon: Icons.check_circle_outline,
                                    text:
                                        "Booking selesai dan ulasan sudah terkirim. Terima kasih!",
                                  )
                                else if (isSelesai && !reviewLater)
                                  const _HintBanner(
                                    icon: Icons.rate_review_outlined,
                                    text:
                                        "Booking selesai. Klik tombol Selesai untuk mengisi ulasan.",
                                  )
                                else if (isSelesai && reviewLater)
                                  const _HintBanner(
                                    icon: Icons.rate_review_outlined,
                                    text:
                                        "Ulasan kamu belum terkirim. Klik tombol Beri Ulasan kapan saja ya.",
                                  )
                                else if (isBatal)
                                  const _HintBanner(
                                    icon: Icons.cancel_outlined,
                                    text: "Booking sudah dibatalkan.",
                                  ),
                              ],
                            ),

                            // ===== Bottom Action Bar =====
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: SafeArea(
                                top: false,
                                child: Container(
                                  padding: EdgeInsets.fromLTRB(
                                    16.w,
                                    10.h,
                                    16.w,
                                    12.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 12,
                                        offset: const Offset(0, -2),
                                      ),
                                    ],
                                  ),
                                  child: Builder(
                                    builder: (_) {
                                      // ✅ FIX: kalau sudah reviewed, tombol SELALU AKTIF
                                      if (reviewed) {
                                        return SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: null,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF2E7D32,
                                              ),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16.r),
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                vertical: 12.h,
                                              ),
                                            ),
                                            child: Text(
                                              "Selesai",
                                              style: TextStyle(
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      // MENUNGGU: Batalkan + Kode
                                      if (isMenunggu) {
                                        return Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: _isCancelling
                                                    ? null
                                                    : () => _cancelBooking(
                                                        bookingId:
                                                            widget.bookingId,
                                                        statusRaw: statusRaw,
                                                      ),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(
                                                    0xFFEB5757,
                                                  ),
                                                  side: const BorderSide(
                                                    color: Color(0xFFEB5757),
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16.r,
                                                        ),
                                                  ),
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 12.h,
                                                  ),
                                                ),
                                                child: Text(
                                                  _isCancelling
                                                      ? "Membatalkan..."
                                                      : "Batalkan",
                                                  style: TextStyle(
                                                    fontSize: 13.sp,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 10.w),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () => _goToCodePage(
                                                  bookingCode:
                                                      bookingCode.isEmpty
                                                      ? widget.bookingId
                                                      : bookingCode,
                                                  bengkelNama: bengkelNama,
                                                  tanggal: tanggal,
                                                  jam: jam,
                                                  vehicleLabel: vehicleLabel,
                                                  nomorPolisi: nomorPolisi,
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFFFFD740,
                                                  ),
                                                  foregroundColor:
                                                      Colors.black87,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16.r,
                                                        ),
                                                  ),
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 12.h,
                                                  ),
                                                ),
                                                child: Text(
                                                  "Kode Booking",
                                                  style: TextStyle(
                                                    fontSize: 13.sp,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }

                                      // PROSES: disabled
                                      if (isProses) {
                                        return SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: null,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.grey.shade300,
                                              foregroundColor:
                                                  Colors.grey.shade700,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16.r),
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                vertical: 12.h,
                                              ),
                                            ),
                                            child: Text(
                                              "Selesai (menunggu bengkel)",
                                              style: TextStyle(
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      // SELESAI: belum review -> flow ulasan
                                      if (isSelesai) {
                                        final label = reviewLater
                                            ? "Beri Ulasan"
                                            : "Selesai";
                                        return SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: () =>
                                                _finishWithReviewFlow(
                                                  reviewed: reviewed,
                                                  bookingId: widget.bookingId,
                                                  bengkelId: bengkelId.isEmpty
                                                      ? "-"
                                                      : bengkelId,
                                                  bengkelNama: bengkelNama,
                                                ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF2E7D32,
                                              ),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16.r),
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                vertical: 12.h,
                                              ),
                                            ),
                                            child: Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      // BATAL / lain-lain
                                      return SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.grey.shade300,
                                            foregroundColor:
                                                Colors.grey.shade700,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16.r),
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              vertical: 12.h,
                                            ),
                                          ),
                                          child: Text(
                                            "Selesai",
                                            style: TextStyle(
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),

                            if (_isCancelling)
                              Positioned.fill(
                                child: IgnorePointer(
                                  ignoring: true,
                                  child: Container(
                                    color: Colors.black.withOpacity(0.05),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _Header({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFD740),
      padding: EdgeInsets.fromLTRB(8.w, 10.h, 16.w, 10.h),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: Colors.black),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _BengkelImage extends StatelessWidget {
  final String url;
  const _BengkelImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final hasUrl = url.trim().isNotEmpty;
    return SizedBox(
      width: 72.w,
      height: 72.w,
      child: hasUrl
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Image.asset("assets/workshop_sample.jpg", fit: BoxFit.cover),
            )
          : Image.asset("assets/workshop_sample.jpg", fit: BoxFit.cover),
    );
  }
}

class _Card extends StatelessWidget {
  final String? title;
  final Widget child;
  const _Card({this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 10.h),
          ],
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.trim().isEmpty ? "-" : value.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[700]),
        SizedBox(width: 8.w),
        SizedBox(
          width: 88.w,
          child: Text(
            label,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _HintBanner extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HintBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFF2994A)),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[800],
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
