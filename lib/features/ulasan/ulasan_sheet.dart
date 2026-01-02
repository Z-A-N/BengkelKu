// lib/features/ulasan/ulasan_sheet.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Future<bool> showUlasanSheet({
  required BuildContext context,
  required String bookingId,
  required String bengkelId,
  required String bengkelNama,
}) async {
  final res = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,

    // ✅ biar gak bisa dismiss tanpa aksi (ini biang bug tombol balik lagi)
    isDismissible: false,
    enableDrag: false,

    builder: (_) => _UlasanSheet(
      bookingId: bookingId,
      bengkelId: bengkelId,
      bengkelNama: bengkelNama,
    ),
  );

  return res == true;
}

class _UlasanSheet extends StatefulWidget {
  final String bookingId;
  final String bengkelId;
  final String bengkelNama;

  const _UlasanSheet({
    required this.bookingId,
    required this.bengkelId,
    required this.bengkelNama,
  });

  @override
  State<_UlasanSheet> createState() => _UlasanSheetState();
}

class _UlasanSheetState extends State<_UlasanSheet> {
  final _commentC = TextEditingController();
  int _rating = 5;
  bool _sending = false;
  bool _closing = false; // ✅ biar gak double pop

  final _quickTags = const <String>[
    "Pelayanan ramah",
    "Pengerjaan cepat",
    "Harga sesuai",
    "Bengkel rapi",
    "Rekomendasi",
  ];
  final Set<String> _selectedTags = {};

  @override
  void dispose() {
    _commentC.dispose();
    super.dispose();
  }

  String _ratingText(int r) {
    if (r >= 5) return "Mantap banget! 🔥";
    if (r == 4) return "Bagus 👍";
    if (r == 3) return "Cukup oke 🙂";
    if (r == 2) return "Kurang 😕";
    return "Buruk 😞";
  }

  Future<void> _closeAsLater() async {
    if (_sending || _closing) return;
    _closing = true;

    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance
          .collection("bookings")
          .doc(widget.bookingId)
          .update({
            "reviewLater": true,
            "reviewLaterAt": FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      Navigator.pop(context, false);
    } catch (e) {
      _closing = false;
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal menyimpan pilihan.\n$e"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_sending) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kamu perlu login dulu."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_rating < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pilih rating dulu ya."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_rating <= 2 && _commentC.text.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Boleh tulis sedikit alasan ya 🙏"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      // ✅ 1 booking = 1 review (docId = bookingId)
      final reviewRef = FirebaseFirestore.instance
          .collection("reviews")
          .doc(widget.bookingId);

      await reviewRef.set({
        "id": widget.bookingId,
        "bookingId": widget.bookingId,
        "bengkelId": widget.bengkelId,
        "bengkelNama": widget.bengkelNama,
        "userId": user.uid,
        "rating": _rating,
        "comment": _commentC.text.trim(),
        "tags": _selectedTags.toList(),
        "createdAt": FieldValue.serverTimestamp(),
      });

      // ⚠️ boleh tetap update booking untuk info cepat,
      // tapi status "reviewed" di riwayat_detail nanti tetap dihitung dari reviews doc (lebih kebal reset)
      await FirebaseFirestore.instance
          .collection("bookings")
          .doc(widget.bookingId)
          .update({
            "reviewed": true,
            "reviewAt": FieldValue.serverTimestamp(),
            "reviewRating": _rating,
            "reviewText": _commentC.text.trim(),
            "reviewTags": _selectedTags.toList(),
            "reviewLater": false,
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Terima kasih! Ulasan kamu terkirim."),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal mengirim ulasan.\n$e"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return WillPopScope(
      // ✅ tombol back HP = dianggap "Nanti saja"
      onWillPop: () async {
        await _closeAsLater();
        return false;
      },
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 18,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ===== HEADER =====
                      Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 8.h),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Beri Ulasan",
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            IconButton(
                              // ✅ X = "Nanti saja" biar gak reset tombol
                              onPressed: _sending ? null : _closeAsLater,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 5.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFFFE082),
                              ),
                            ),
                            child: Text(
                              widget.bengkelNama,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Divider(height: 1, color: Colors.grey.shade200),

                      // ===== BODY =====
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 12.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(14.w),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                    color: const Color(0xFFFFE082),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.star_rounded,
                                          color: Color(0xFFFFC107),
                                        ),
                                        SizedBox(width: 6.w),
                                        Text(
                                          "Rating",
                                          style: TextStyle(
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _ratingText(_rating),
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 10.h),
                                    Row(
                                      children: List.generate(5, (idx) {
                                        final i = idx + 1;
                                        final active = i <= _rating;
                                        return InkWell(
                                          onTap: _sending
                                              ? null
                                              : () =>
                                                    setState(() => _rating = i),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 2.w,
                                            ),
                                            child: Icon(
                                              active
                                                  ? Icons.star_rounded
                                                  : Icons.star_border_rounded,
                                              size: 34.sp,
                                              color: active
                                                  ? const Color(0xFFFFC107)
                                                  : Colors.grey[400],
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 12.h),

                              Text(
                                "Boleh pilih yang cocok (opsional)",
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey[800],
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Wrap(
                                spacing: 8.w,
                                runSpacing: 8.h,
                                children: _quickTags.map((t) {
                                  final on = _selectedTags.contains(t);
                                  return FilterChip(
                                    selected: on,
                                    label: Text(
                                      t,
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    onSelected: _sending
                                        ? null
                                        : (v) => setState(() {
                                            if (v) {
                                              _selectedTags.add(t);
                                            } else {
                                              _selectedTags.remove(t);
                                            }
                                          }),
                                    selectedColor: const Color(0xFFFFD740),
                                    backgroundColor: const Color(0xFFF5F5F5),
                                    checkmarkColor: Colors.black87,
                                    shape: StadiumBorder(
                                      side: BorderSide(
                                        color: on
                                            ? const Color(0xFFFFC107)
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),

                              SizedBox(height: 12.h),

                              Text(
                                "Ulasan (opsional)",
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey[800],
                                ),
                              ),
                              SizedBox(height: 8.h),
                              TextField(
                                controller: _commentC,
                                minLines: 3,
                                maxLines: 5,
                                maxLength: 250,
                                enabled: !_sending,
                                decoration: InputDecoration(
                                  hintText: "Ceritakan pengalaman kamu…",
                                  filled: true,
                                  fillColor: const Color(0xFFF7F7F7),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12.w,
                                    vertical: 12.h,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14.r),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14.r),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14.r),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFFFD740),
                                      width: 1.4,
                                    ),
                                  ),
                                ),
                                style: TextStyle(fontSize: 12.sp),
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                "Ulasan kamu membantu bengkel jadi lebih baik ✨",
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: Colors.grey[700],
                                ),
                              ),
                              SizedBox(height: 6.h),
                            ],
                          ),
                        ),
                      ),

                      // ===== FOOTER =====
                      SafeArea(
                        top: false,
                        child: Container(
                          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 14,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _sending ? null : _closeAsLater,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.black87,
                                    side: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14.r),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      vertical: 12.h,
                                    ),
                                  ),
                                  child: Text(
                                    _sending ? "..." : "Nanti saja",
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
                                  onPressed: _sending ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFD740),
                                    foregroundColor: Colors.black87,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14.r),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      vertical: 12.h,
                                    ),
                                  ),
                                  child: Text(
                                    _sending ? "Mengirim..." : "Kirim Ulasan",
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_sending)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(color: Colors.white.withOpacity(0.35)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
