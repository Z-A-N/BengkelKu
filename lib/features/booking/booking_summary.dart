// lib/screen/booking/booking_summary.dart
// ignore_for_file: deprecated_member_use, unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/bengkel_model.dart';
import 'booking_success.dart';

/// 1 item layanan yang dipilih user
class LayananItem {
  final String id;
  final String nama;
  final int harga;

  LayananItem({required this.id, required this.nama, required this.harga});
}

class BookingSummaryPage extends StatefulWidget {
  final Bengkel bengkel;

  /// list layanan yang dikirim dari halaman detail
  final List<LayananItem> layananDipilih;

  const BookingSummaryPage({
    super.key,
    required this.bengkel,
    required this.layananDipilih,
  });

  @override
  State<BookingSummaryPage> createState() => _BookingSummaryPageState();
}

class _VehicleOption {
  final String id;
  final String jenis;
  final String nomorPolisi;
  final String merek;
  final String model;
  final String tahun;
  final String km;

  const _VehicleOption({
    required this.id,
    required this.jenis,
    required this.nomorPolisi,
    required this.merek,
    required this.model,
    required this.tahun,
    required this.km,
  });

  /// ✅ Dropdown label: "Motor • Honda Vario 125 • 2013"
  /// fallback: kalau tahun kosong -> pakai nopol
  String get label {
    final brandModel = [
      merek.trim(),
      model.trim(),
    ].where((e) => e.isNotEmpty).join(' ').trim();

    final type = jenis.trim();
    final year = tahun.trim();
    final plate = nomorPolisi.trim();

    final parts = <String>[];
    if (type.isNotEmpty) parts.add(type);
    if (brandModel.isNotEmpty) parts.add(brandModel);

    if (year.isNotEmpty) {
      parts.add(year);
    } else if (plate.isNotEmpty) {
      parts.add(plate);
    }

    return parts.isEmpty ? 'Kendaraan' : parts.join(' • ');
  }

  static String _s(dynamic v) => (v == null) ? '' : v.toString();

  factory _VehicleOption.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final data = d.data();
    return _VehicleOption(
      id: d.id,
      jenis: _s(data['jenis']),
      nomorPolisi: _s(data['nomorPolisi']),
      merek: _s(data['merek']),
      model: _s(data['model']),
      tahun: _s(data['tahun']),
      km: _s(data['km']),
    );
  }
}

class _BookingSummaryPageState extends State<BookingSummaryPage> {
  late final List<DateTime> _tanggalOptions;
  late DateTime _selectedTanggal;
  String? _selectedJam;

  final _nomorPolisiC = TextEditingController();
  final _catatanC = TextEditingController();

  String _metodePembayaran = "Bayar Ditempat";
  bool _isSaving = false;

  late List<LayananItem> _layananDipilih;

  static const List<String> _timeSlots = [
    "Kurang dari 30 Menit",
    "09:00 - 11:00",
    "11:00 - 13:00",
    "13:00 - 15:00",
    "15:00 - 17:00",
    "17:00 - 19:00",
    "19:00 - 21:00",
  ];

  // ===== VEHICLE DROPDOWN =====
  bool _vehicleLoading = true;
  List<_VehicleOption> _vehicles = const [];
  String? _selectedVehicleId;
  String? _selectedJenis;

  @override
  void initState() {
    super.initState();

    _layananDipilih = List<LayananItem>.from(widget.layananDipilih);

    final now = DateTime.now();
    _tanggalOptions = List.generate(
      5,
      (i) => DateTime(now.year, now.month, now.day).add(Duration(days: i)),
    );
    _selectedTanggal = _tanggalOptions.first;

    _loadVehiclesFromUser();
  }

  @override
  void dispose() {
    _nomorPolisiC.dispose();
    _catatanC.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  void _popWithResult() {
    Navigator.pop(context, _layananDipilih);
  }

  String _rupiahInt(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write('.');
    }
    return "Rp ${buf.toString()}";
  }

  // ✅ label kendaraan: jenis + merek model + tahun (bukan nopol)
  String _makeVehicleLabel({
    required String jenis,
    required String merek,
    required String model,
    required String tahun,
    required String plateFallback,
  }) {
    final brandModel = [
      merek.trim(),
      model.trim(),
    ].where((e) => e.isNotEmpty).join(' ').trim();

    final parts = <String>[];
    if (jenis.trim().isNotEmpty) parts.add(jenis.trim());
    if (brandModel.isNotEmpty) parts.add(brandModel);

    final y = tahun.trim();
    if (y.isNotEmpty) {
      parts.add(y);
    } else {
      final p = plateFallback.trim();
      if (p.isNotEmpty) parts.add(p);
    }

    return parts.isEmpty ? "Kendaraan" : parts.join(" • ");
  }

  _VehicleOption? _getSelectedVehicle() {
    if (_vehicles.isEmpty || _selectedVehicleId == null) return null;
    try {
      return _vehicles.firstWhere((e) => e.id == _selectedVehicleId);
    } catch (_) {
      return _vehicles.first;
    }
  }

  /// ✅ AUTO buat room chat bengkel setelah booking sukses.
  /// - chatId deterministik: bengkel_{bengkelId}_{uid}
  /// - kalau chat udah ada -> update ringan (title/lastBookingId) TANPA sentuh lastMessageAt
  Future<void> _ensureBengkelChatAfterBooking({
    required String uid,
    required String bengkelId,
    required String bengkelNama,
    required String bookingId,
  }) async {
    if (bengkelId.trim().isEmpty) return;

    final chatId = "bengkel_${bengkelId}_$uid";
    final chatRef = FirebaseFirestore.instance.collection("chats").doc(chatId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(chatRef);

      final peerId = "bengkel:$bengkelId";

      if (!snap.exists) {
        tx.set(chatRef, {
          "chatId": chatId,
          "type": "bengkel",
          "title": bengkelNama,
          "bengkelId": bengkelId,
          "lastBookingId": bookingId,
          "participants": [uid, peerId],
          "unread": {uid: 0, peerId: 0},
          "lastMessage": "",
          "lastMessageAt": FieldValue.serverTimestamp(),
          "createdAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        // chat sudah ada -> jangan ganggu lastMessageAt (biar sorting chat gak berubah)
        tx.set(chatRef, {
          "type": "bengkel",
          "title": bengkelNama,
          "bengkelId": bengkelId,
          "lastBookingId": bookingId,
          "participants": [uid, peerId], // keep konsisten
          "unread": {uid: 0, peerId: 0},
        }, SetOptions(merge: true));
      }
    });
  }

  // =====================================================
  //  LOAD VEHICLE FROM: users/{uid}/vehicle/*
  // =====================================================
  Future<void> _loadVehiclesFromUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _vehicleLoading = false;
        _vehicles = const [];
      });
      return;
    }

    try {
      final qs = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('vehicle')
          .get();

      final options = qs.docs
          .map((d) => _VehicleOption.fromDoc(d))
          .toList(growable: false);

      _VehicleOption? def;
      for (final v in options) {
        if (v.id == 'main') {
          def = v;
          break;
        }
      }
      def ??= options.isNotEmpty ? options.first : null;

      if (!mounted) return;
      setState(() {
        _vehicles = options;
        _vehicleLoading = false;
        _selectedVehicleId = def?.id;
        _selectedJenis = def?.jenis;
      });

      if (def != null &&
          _nomorPolisiC.text.trim().isEmpty &&
          def.nomorPolisi.trim().isNotEmpty) {
        _nomorPolisiC.text = def.nomorPolisi.trim();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _vehicleLoading = false;
        _vehicles = const [];
      });
    }
  }

  void _onSelectVehicle(String? vehicleId) {
    if (vehicleId == null) return;

    final pick = _vehicles.firstWhere(
      (e) => e.id == vehicleId,
      orElse: () => _vehicles.first,
    );

    setState(() {
      _selectedVehicleId = pick.id;
      _selectedJenis = pick.jenis;
    });

    if (pick.nomorPolisi.trim().isNotEmpty) {
      _nomorPolisiC.text = pick.nomorPolisi.trim();
    }
  }

  // =====================================================
  //  SIMPAN BOOKING KE FIRESTORE + AUTO CHAT
  // =====================================================
  Future<void> _saveBooking() async {
    FocusScope.of(context).unfocus();

    if (_layananDipilih.isEmpty) {
      _toast("Kamu belum memilih layanan. Pilih minimal 1 layanan dulu ya.");
      return;
    }
    if (_selectedJam == null) {
      _toast("Pilih jam kunjungan dulu ya.");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast("Kamu perlu login dulu untuk melanjutkan booking.");
      return;
    }

    if ((_selectedJenis ?? '').trim().isEmpty) {
      _toast("Pilih kendaraan dulu ya.");
      return;
    }

    final selectedVehicle = _getSelectedVehicle();
    final vJenis = (_selectedJenis ?? '').trim();
    final vMerek = (selectedVehicle?.merek ?? '').trim();
    final vModel = (selectedVehicle?.model ?? '').trim();
    final vTahun = (selectedVehicle?.tahun ?? '').trim();
    final vKm = (selectedVehicle?.km ?? '').trim();
    final vPlate = _nomorPolisiC.text.trim();

    final vehicleLabel = _makeVehicleLabel(
      jenis: vJenis,
      merek: vMerek,
      model: vModel,
      tahun: vTahun,
      plateFallback: vPlate,
    );

    setState(() => _isSaving = true);

    try {
      final bookingRef = FirebaseFirestore.instance
          .collection('bookings')
          .doc();

      // 1) simpan booking
      await bookingRef.set({
        "id": bookingRef.id,
        "bookingCode": bookingRef.id,

        "userId": user.uid,
        "bengkelId": widget.bengkel.id,
        "bengkelNama": widget.bengkel.nama,
        "bengkelAlamat": widget.bengkel.alamat,
        "bengkelFoto": widget.bengkel.foto,

        "layanan": _layananDipilih
            .map((e) => {"id": e.id, "nama": e.nama, "harga": e.harga})
            .toList(),

        "tanggal": Timestamp.fromDate(_selectedTanggal),
        "jam": _selectedJam!,

        "vehicleId": _selectedVehicleId,
        "jenisKendaraan": vJenis,
        "nomorPolisi": vPlate,

        "vehicleLabel": vehicleLabel,
        "vehicleMerek": vMerek,
        "vehicleModel": vModel,
        "vehicleTahun": vTahun,
        "vehicleKm": vKm,

        "catatan": _catatanC.text.trim(),
        "metodePembayaran": _metodePembayaran,
        "status": "menunggu",
        "createdAt": FieldValue.serverTimestamp(),
      });

      // 2) AUTO buat chat room bengkel (kalau belum ada)
      await _ensureBengkelChatAfterBooking(
        uid: user.uid,
        bengkelId: widget.bengkel.id,
        bengkelNama: widget.bengkel.nama,
        bookingId: bookingRef.id,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      // 3) ke success page
      final reset = await Navigator.push<bool>(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => BookingSuccessPage(
            bookingId: bookingRef.id,
            bengkel: widget.bengkel,
            layananDipilih: List<LayananItem>.from(_layananDipilih),
            tanggal: _selectedTanggal,
            jam: _selectedJam!,
            jenisKendaraan: vJenis,
            nomorPolisi: vPlate,
            catatan: _catatanC.text.trim(),
            metodePembayaran: _metodePembayaran,
            vehicleLabel: vehicleLabel,
            vehicleTahun: vTahun,
            vehicleKm: vKm,
          ),
          transitionsBuilder: (_, animation, __, child) {
            final offsetAnim =
                Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                );
            return SlideTransition(position: offsetAnim, child: child);
          },
        ),
      );

      if (!mounted) return;
      if (reset == true) Navigator.pop(context, <LayananItem>[]);
    } catch (e) {
      if (!mounted) return;
      _toast("Gagal menyimpan booking. Coba lagi ya.\n$e");
      setState(() => _isSaving = false);
    }
  }

  // =====================================================
  //  BUILD UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final total = _layananDipilih.fold<int>(0, (acc, item) => acc + item.harga);
    final scrollBottomPadding = 190.h;

    return WillPopScope(
      onWillPop: () async {
        _popWithResult();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFD740),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: _popWithResult,
          ),
          title: const Text(
            "Ringkasan Booking",
            style: TextStyle(color: Colors.black87),
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16.w,
                  16.h,
                  16.w,
                  scrollBottomPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBengkelCard(),
                    SizedBox(height: 14.h),
                    _buildTanggalSection(),
                    SizedBox(height: 14.h),
                    _buildJamSection(),
                    SizedBox(height: 14.h),
                    _buildLayananDipilihSection(),
                    SizedBox(height: 14.h),
                    _buildInformasiKendaraanSection(),
                    SizedBox(height: 14.h),
                    _buildMetodePembayaranSection(),
                  ],
                ),
              ),

              // Bottom Bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTotalAndConfirmButton(total),
                        SizedBox(height: 14.h),
                        SizedBox(
                          width: double.infinity,
                          height: 46.h,
                          child: OutlinedButton(
                            onPressed: _isSaving ? null : _popWithResult,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.grey.shade400,
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24.r),
                              ),
                            ),
                            child: Text(
                              "Batalkan",
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (_isSaving)
                Container(
                  color: Colors.black.withOpacity(0.2),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- BENGKEL CARD ----------------
  Widget _buildBengkelCard() {
    final fotoUrl = widget.bengkel.foto.trim();
    final hasUrl = fotoUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(12.w),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: SizedBox(
              width: 70.w,
              height: 70.w,
              child: hasUrl
                  ? Image.network(
                      fotoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/workshop_sample.jpg',
                        fit: BoxFit.cover,
                      ),
                    )
                  : Image.asset(
                      'assets/workshop_sample.jpg',
                      fit: BoxFit.cover,
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
                SizedBox(height: 4.h),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.orange,
                      size: 16,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      widget.bengkel.rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
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
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: widget.bengkel.buka
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Text(
              widget.bengkel.buka ? "Buka sekarang" : "Tutup",
              style: TextStyle(
                color: widget.bengkel.buka
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFB71C1C),
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- TANGGAL ----------------
  Widget _buildTanggalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Pilih Tanggal Kunjungan",
          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8.h),
        SizedBox(
          height: 80.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _tanggalOptions.length,
            separatorBuilder: (_, __) => SizedBox(width: 8.w),
            itemBuilder: (_, index) {
              final date = _tanggalOptions[index];
              final isSelected = date == _selectedTanggal;

              final hari = _namaHari(date.weekday);
              final tanggal = date.day.toString().padLeft(2, '0');
              final bulan = _namaBulanPendek(date.month);

              return GestureDetector(
                onTap: () => setState(() => _selectedTanggal = date),
                child: Container(
                  width: 60.w,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFFD740) : Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFFC107)
                          : Colors.grey.shade300,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        hari,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: isSelected ? Colors.black : Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        tanggal,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.black : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        bulan,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: isSelected ? Colors.black : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _namaHari(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return "Sen";
      case DateTime.tuesday:
        return "Sel";
      case DateTime.wednesday:
        return "Rab";
      case DateTime.thursday:
        return "Kam";
      case DateTime.friday:
        return "Jum";
      case DateTime.saturday:
        return "Sab";
      case DateTime.sunday:
        return "Min";
      default:
        return "";
    }
  }

  String _namaBulanPendek(int month) {
    const names = [
      "",
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
    return names[month];
  }

  // ---------------- JAM ----------------
  Widget _buildJamSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Pilih Jam Kunjungan",
          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8.h),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: _timeSlots.map((slot) {
              return Column(
                children: [
                  ListTile(
                    dense: true,
                    title: Text(slot, style: TextStyle(fontSize: 13.sp)),
                    trailing: Radio<String>(
                      value: slot,
                      groupValue: _selectedJam,
                      onChanged: (v) => setState(() => _selectedJam = v),
                      activeColor: const Color(0xFFDB0C0C),
                    ),
                    onTap: () => setState(() => _selectedJam = slot),
                  ),
                  if (slot != _timeSlots.last)
                    Divider(height: 1, color: Colors.grey.shade200),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ---------------- LAYANAN ----------------
  Widget _buildLayananDipilihSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Layanan Dipilih",
          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8.h),
        if (_layananDipilih.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              "Belum ada layanan. Kamu bisa kembali untuk memilih layanan dulu.",
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
            ),
          )
        else
          Column(
            children: [
              for (final item in _layananDipilih) ...[
                Container(
                  margin: EdgeInsets.only(bottom: 8.h),
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.nama,
                          style: TextStyle(fontSize: 13.sp),
                        ),
                      ),
                      Text(
                        _rupiahInt(item.harga),
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFDB0C0C),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      IconButton(
                        onPressed: () =>
                            setState(() => _layananDipilih.remove(item)),
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _popWithResult,
                  child: const Text("Tambah layanan lain"),
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ---------------- INFORMASI KENDARAAN ----------------
  Widget _buildInformasiKendaraanSection() {
    final disabled = _vehicleLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Informasi Kendaraan",
          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: Colors.grey.shade300, width: 1.4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedVehicleId,
              hint: Text(
                disabled
                    ? "Memuat kendaraan..."
                    : (_vehicles.isEmpty
                          ? "Belum ada kendaraan"
                          : "Pilih kendaraan"),
                style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
              ),
              items: _vehicles.map((v) {
                return DropdownMenuItem<String>(
                  value: v.id,
                  child: Text(v.label, style: TextStyle(fontSize: 13.sp)),
                );
              }).toList(),
              onChanged: (disabled || _vehicles.isEmpty)
                  ? null
                  : _onSelectVehicle,
            ),
          ),
        ),
        SizedBox(height: 10.h),
        _buildTextField(
          label: "Nomor polisi",
          hint: "R 1234 XX",
          controller: _nomorPolisiC,
        ),
        SizedBox(height: 10.h),
        _buildTextField(
          label: "Catatan (opsional)",
          hint: "Contoh: mesin agak kasar",
          controller: _catatanC,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    const borderRadius = 14.0;

    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(color: color, width: 1.4),
    );

    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(fontSize: 12.sp, color: Colors.black87),
        hintStyle: TextStyle(fontSize: 13.sp, color: Colors.grey[500]),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        enabledBorder: border(Colors.grey.shade300),
        focusedBorder: border(const Color(0xFF7E57C2)),
        border: border(Colors.grey.shade300),
      ),
      style: TextStyle(fontSize: 13.sp),
    );
  }

  // ---------------- METODE PEMBAYARAN ----------------
  IconData _payIcon(String method) {
    switch (method) {
      case "Bayar Ditempat":
        return Icons.payments_outlined;
      case "Transfer Bank":
        return Icons.account_balance_outlined;
      case "E-Wallet":
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.payments_outlined;
    }
  }

  Widget _buildMetodePembayaranSection() {
    const methods = ["Bayar Ditempat", "Transfer Bank", "E-Wallet"];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Metode Pembayaran",
          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8.h),
        Column(
          children: methods.map((m) {
            final selected = _metodePembayaran == m;

            return GestureDetector(
              onTap: () => setState(() => _metodePembayaran = m),
              child: Container(
                margin: EdgeInsets.only(bottom: 8.h),
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(_payIcon(m), size: 20, color: Colors.black87),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        m,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFFDB0C0C),
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ---------------- TOTAL & KONFIRMASI ----------------
  Widget _buildTotalAndConfirmButton(int total) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Total Pembayaran",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              _rupiahInt(total),
              style: const TextStyle(
                color: Color(0xFFDB0C0C),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        SizedBox(
          width: double.infinity,
          height: 46.h,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveBooking,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD740),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.r),
              ),
            ),
            child: Text(
              _isSaving ? "Menyimpan..." : "Konfirmasi Booking",
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.sp),
            ),
          ),
        ),
      ],
    );
  }
}
