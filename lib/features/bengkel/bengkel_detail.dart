// ignore_for_file: deprecated_member_use, dead_code, unnecessary_null_comparison, unnecessary_underscores, curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/bengkel_model.dart';
import '../booking/booking_summary.dart';
import '../chat/chat_room.dart';

class BengkelDetailPage extends StatefulWidget {
  final Bengkel bengkel;

  const BengkelDetailPage({super.key, required this.bengkel});

  @override
  State<BengkelDetailPage> createState() => _BengkelDetailPageState();
}

class _BengkelDetailPageState extends State<BengkelDetailPage> {
  /// Shared state: layanan yang dipilih (dipakai tab layanan + bottom bar)
  final ValueNotifier<List<LayananItem>> _selectedLayanan =
      ValueNotifier<List<LayananItem>>([]);

  @override
  void dispose() {
    _selectedLayanan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bengkel = widget.bengkel;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: _BottomActionBar(
          bengkel: bengkel,
          selectedLayanan: _selectedLayanan,
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(child: _HeaderImage(fotoUrl: bengkel.foto)),
              SliverToBoxAdapter(child: _BengkelSummary(bengkel: bengkel)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    indicatorColor: const Color(0xFFFFD740),
                    labelColor: Colors.black87,
                    unselectedLabelColor: Colors.black54,
                    indicatorWeight: 3,
                    labelStyle: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: const [
                      Tab(text: "Info"),
                      Tab(text: "Layanan"),
                      Tab(text: "Ulasan"),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              _InfoTab(bengkel: bengkel),
              _LayananTab(bengkel: bengkel, selectedLayanan: _selectedLayanan),

              // ✅ FIX: widget ulasan sekarang ADA
              _UlasanTab(bengkelId: bengkel.id),
            ],
          ),
        ),
      ),
    );
  }
}

///////////////////////////////////////////////////////////////////////////
/// HEADER FOTO + ICON
///////////////////////////////////////////////////////////////////////////

class _HeaderImage extends StatelessWidget {
  final String fotoUrl;

  const _HeaderImage({required this.fotoUrl});

  @override
  Widget build(BuildContext context) {
    final hasUrl = fotoUrl.trim().isNotEmpty;

    return SizedBox(
      height: 230.h,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: hasUrl
                ? Image.network(
                    fotoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/workshop_sample.jpg',
                      fit: BoxFit.cover,
                    ),
                  )
                : Image.asset('assets/workshop_sample.jpg', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 60.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0),
                      Colors.black.withOpacity(0.25),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundIconButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.pop(context),
                  ),
                  _RoundIconButton(icon: Icons.favorite_border, onTap: () {}),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: EdgeInsets.all(8.w),
          child: Icon(icon, size: 20.sp, color: Colors.black87),
        ),
      ),
    );
  }
}

///////////////////////////////////////////////////////////////////////////
/// RINGKASAN BENGKEL
///////////////////////////////////////////////////////////////////////////

class _BengkelSummary extends StatelessWidget {
  final Bengkel bengkel;

  const _BengkelSummary({required this.bengkel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bengkel.nama,
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Colors.orange, size: 18),
              SizedBox(width: 4.w),
              Text(
                bengkel.rating.toStringAsFixed(1),
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
              ),
              SizedBox(width: 8.w),
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: Colors.grey[700],
              ),
              SizedBox(width: 4.w),
              Text(
                "0.2 km",
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: bengkel.buka
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Text(
                  bengkel.buka ? "Buka" : "Tutup",
                  style: TextStyle(
                    color: bengkel.buka
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFB71C1C),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            bengkel.deskripsi,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}

///////////////////////////////////////////////////////////////////////////
/// TAB INFO
///////////////////////////////////////////////////////////////////////////

class _InfoTab extends StatelessWidget {
  final Bengkel bengkel;

  const _InfoTab({required this.bengkel});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 100.h),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.place_outlined, size: 22),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(bengkel.alamat, style: TextStyle(fontSize: 13.sp)),
            ),
          ],
        ),
        SizedBox(height: 20.h),
        SizedBox(
          width: double.infinity,
          height: 44.h,
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFDB0C0C), width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: Text(
              "Lihat di Peta",
              style: TextStyle(
                color: const Color(0xFFDB0C0C),
                fontWeight: FontWeight.w600,
                fontSize: 13.sp,
              ),
            ),
          ),
        ),
        SizedBox(height: 26.h),
        Text(
          "Jam Operasional",
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 12.h),
        const _InfoDay(label: "Senin - Jumat", time: "08:00 - 16:00"),
        const _InfoDay(label: "Sabtu", time: "08:00 - 16:00"),
        const _InfoDay(label: "Minggu", time: "08:00 - 16:00"),
        SizedBox(height: 26.h),
        Text(
          "Kontak",
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            const Icon(Icons.phone_outlined, size: 20),
            SizedBox(width: 8.w),
            Text(bengkel.telepon, style: TextStyle(fontSize: 13.sp)),
            const Spacer(),
            Text(
              "Hubungi",
              style: TextStyle(
                color: const Color(0xFFDB0C0C),
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoDay extends StatelessWidget {
  final String label;
  final String time;

  const _InfoDay({required this.label, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 13.sp)),
          ),
          Text(
            time,
            style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}

///////////////////////////////////////////////////////////////////////////
/// TAB LAYANAN
///////////////////////////////////////////////////////////////////////////

class _LayananTab extends StatefulWidget {
  final Bengkel bengkel;
  final ValueNotifier<List<LayananItem>> selectedLayanan;

  const _LayananTab({required this.bengkel, required this.selectedLayanan});

  @override
  State<_LayananTab> createState() => _LayananTabState();
}

class _LayananTabState extends State<_LayananTab> {
  bool _isSelected(List<LayananItem> selected, String id) {
    return selected.any((e) => e.id == id);
  }

  void _toggleLayanan(QueryDocumentSnapshot doc, bool selectedNow) {
    final hargaNum = (doc['harga'] ?? 0) as num;

    final item = LayananItem(
      id: doc.id,
      nama: (doc['nama'] ?? '-').toString(),
      harga: hargaNum.toInt(),
    );

    final current = widget.selectedLayanan.value;

    if (selectedNow) {
      widget.selectedLayanan.value = current
          .where((e) => e.id != item.id)
          .toList();
    } else {
      widget.selectedLayanan.value = [...current, item];
    }
  }

  @override
  Widget build(BuildContext context) {
    final layananRef = FirebaseFirestore.instance
        .collection('bengkel')
        .doc(widget.bengkel.id)
        .collection('layanan')
        .orderBy('harga', descending: false);

    return StreamBuilder<QuerySnapshot>(
      stream: layananRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text("Gagal memuat layanan"));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text(
              "Belum ada layanan terdaftar",
              style: TextStyle(fontSize: 13.sp),
            ),
          );
        }

        return ValueListenableBuilder<List<LayananItem>>(
          valueListenable: widget.selectedLayanan,
          builder: (context, selected, _) {
            return ListView(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 100.h),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Layanan Tersedia",
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (selected.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3CD),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          "${selected.length} dipilih",
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 10.h),
                for (final doc in docs) ...[
                  Builder(
                    builder: (_) {
                      final selectedNow = _isSelected(selected, doc.id);
                      return _ServiceItem(
                        title: (doc['nama'] ?? '-').toString(),
                        subtitle: (doc['deskripsi'] ?? '').toString(),
                        price: (doc['harga'] ?? 0).toString(),
                        filled: !selectedNow,
                        buttonText: selectedNow ? "Batalkan" : "Tambah",
                        onPressed: () => _toggleLayanan(doc, selectedNow),
                      );
                    },
                  ),
                  SizedBox(height: 10.h),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _ServiceItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final String buttonText;
  final bool filled;
  final VoidCallback onPressed;

  const _ServiceItem({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.buttonText,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: Image.asset(
              "assets/service_sample.jpg",
              width: 80.w,
              height: 70.h,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[700]),
                ),
                SizedBox(height: 6.h),
                Text(
                  "Rp $price",
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFDB0C0C),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          SizedBox(
            height: 34.h,
            child: filled
                ? ElevatedButton(
                    onPressed: onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD740),
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                    ),
                    child: Text(
                      buttonText,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : OutlinedButton(
                    onPressed: onPressed,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFFDB0C0C),
                        width: 1.4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                    ),
                    child: Text(
                      buttonText,
                      style: TextStyle(
                        color: const Color(0xFFDB0C0C),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

///////////////////////////////////////////////////////////////////////////
/// ✅ TAB ULASAN (FIX: sekarang ADA)
///////////////////////////////////////////////////////////////////////////

class _UlasanTab extends StatelessWidget {
  final String bengkelId;

  const _UlasanTab({required this.bengkelId});

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return "${diff.inSeconds} dtk lalu";
    if (diff.inMinutes < 60) return "${diff.inMinutes} mnt lalu";
    if (diff.inHours < 24) return "${diff.inHours} jam lalu";
    if (diff.inDays < 7) return "${diff.inDays} hari lalu";
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 4) return "$weeks minggu lalu";
    final months = (diff.inDays / 30).floor();
    if (months < 12) return "$months bulan lalu";
    final years = (diff.inDays / 365).floor();
    return "$years tahun lalu";
  }

  @override
  Widget build(BuildContext context) {
    final reviewRef = FirebaseFirestore.instance
        .collection('bengkel')
        .doc(bengkelId)
        .collection('ulasan')
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: reviewRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text("Gagal memuat ulasan"));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text("Belum ada ulasan", style: TextStyle(fontSize: 13.sp)),
          );
        }

        final ratingNums = docs
            .map(
              (d) => d['rating'] is num ? (d['rating'] as num).toDouble() : 0.0,
            )
            .toList(growable: false);

        final avgRating = ratingNums.isEmpty
            ? 0.0
            : ratingNums.reduce((a, b) => a + b) / ratingNums.length;

        final counts = List<int>.filled(6, 0);
        for (final r in ratingNums) {
          final star = r.round().clamp(1, 5);
          counts[star] += 1;
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 100.h),
          children: [
            _RatingSummary(
              average: avgRating,
              total: ratingNums.length,
              starCounts: counts,
            ),
            SizedBox(height: 20.h),
            for (final d in docs) ...[
              _ReviewCard(
                name: (d['namaUser'] ?? 'Anonim').toString(),
                rating: d['rating'] is num
                    ? (d['rating'] as num).toDouble()
                    : 0.0,
                timeAgo: () {
                  final createdAt = d['createdAt'];
                  if (createdAt is Timestamp)
                    return _timeAgo(createdAt.toDate());
                  return "";
                }(),
                text: (d['komentar'] ?? '').toString(),
              ),
              const Divider(height: 30),
            ],
          ],
        );
      },
    );
  }
}

class _RatingSummary extends StatelessWidget {
  final double average;
  final int total;
  final List<int> starCounts;

  const _RatingSummary({
    required this.average,
    required this.total,
    required this.starCounts,
  });

  @override
  Widget build(BuildContext context) {
    double ratio(int count) => total == 0 ? 0.0 : count / total;

    Widget bar(double v) {
      return LinearProgressIndicator(
        value: v,
        minHeight: 5.h,
        backgroundColor: Colors.grey.shade200,
        valueColor: const AlwaysStoppedAnimation(Color(0xFF00796B)),
      );
    }

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _RatingRow(label: "5", bar: bar(ratio(starCounts[5]))),
                SizedBox(height: 4.h),
                _RatingRow(label: "4", bar: bar(ratio(starCounts[4]))),
                SizedBox(height: 4.h),
                _RatingRow(label: "3", bar: bar(ratio(starCounts[3]))),
                SizedBox(height: 4.h),
                _RatingRow(label: "2", bar: bar(ratio(starCounts[2]))),
                SizedBox(height: 4.h),
                _RatingRow(label: "1", bar: bar(ratio(starCounts[1]))),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                average.toStringAsFixed(1),
                style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 6.h),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: i < average.round()
                        ? Colors.orange
                        : Colors.grey[300],
                  ),
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                "$total Reviews",
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[700]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final String label;
  final Widget bar;

  const _RatingRow({required this.label, required this.bar});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 11.sp)),
        SizedBox(width: 4.w),
        const Icon(Icons.star_rounded, size: 12, color: Colors.orange),
        SizedBox(width: 6.w),
        Expanded(child: bar),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String name;
  final double rating;
  final String timeAgo;
  final String text;

  const _ReviewCard({
    required this.name,
    required this.rating,
    required this.timeAgo,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final filled = rating.round().clamp(0, 5);

    return Column(
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundImage: AssetImage("assets/avatar_sample.jpg"),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: i < filled
                                ? Colors.orange
                                : Colors.grey[300],
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      if (timeAgo.isNotEmpty)
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey[700],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.more_vert, color: Colors.grey[700]),
          ],
        ),
        SizedBox(height: 8.h),
        Text(
          text,
          style: TextStyle(fontSize: 12.sp, color: Colors.grey[800]),
        ),
      ],
    );
  }
}

///////////////////////////////////////////////////////////////////////////
/// BOTTOM BUTTON (Smart)
///////////////////////////////////////////////////////////////////////////

class _BottomActionBar extends StatelessWidget {
  final Bengkel bengkel;
  final ValueNotifier<List<LayananItem>> selectedLayanan;

  const _BottomActionBar({
    required this.bengkel,
    required this.selectedLayanan,
  });

  Stream<bool> _canChatStream(String uid) {
    if (bengkel.id.trim().isEmpty) return Stream.value(false);

    final query = FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: uid)
        .where('bengkelId', isEqualTo: bengkel.id)
        .limit(1);

    return query.snapshots(includeMetadataChanges: true).map((snap) {
      if (snap.metadata.isFromCache) return false;
      return snap.docs.isNotEmpty;
    });
  }

  /// ✅ FIX: implement buka chat (tanpa query/index)
  Future<void> _openChat(BuildContext context, User user) async {
    if (bengkel.id.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Bengkel belum punya ID.")));
      return;
    }

    // chatId deterministik -> gak perlu query Firestore
    final chatId = "bengkel_${bengkel.id}_${user.uid}";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(
          chatId: chatId,
          title: bengkel.nama,
          bengkelId: bengkel.id,
        ),
      ),
    );
  }

  void _showPickServiceDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Pilih layanan",
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  "Silakan pilih minimal satu layanan.",
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 24.h),
                SizedBox(
                  width: double.infinity,
                  height: 44.h,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDB0C0C),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                    ),
                    child: Text(
                      "OK",
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _buildBar(context, canChat: false, user: null);

    return StreamBuilder<bool>(
      stream: _canChatStream(user.uid),
      initialData: false,
      builder: (context, snap) {
        final canChat = (snap.hasError) ? false : (snap.data ?? false);
        return _buildBar(context, canChat: canChat, user: user);
      },
    );
  }

  Widget _buildBar(
    BuildContext context, {
    required bool canChat,
    required User? user,
  }) {
    final chatEnabled = canChat && user != null;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16.w,
        8.h,
        16.w,
        12.h + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: chatEnabled ? () => _openChat(context, user) : null,
              style: OutlinedButton.styleFrom(
                backgroundColor: chatEnabled
                    ? Colors.transparent
                    : Colors.grey.shade200,
                side: BorderSide(
                  color: chatEnabled
                      ? const Color(0xFFDB0C0C)
                      : Colors.grey.shade400,
                  width: 1.4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.r),
                ),
                padding: EdgeInsets.symmetric(vertical: 10.h),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                    color: chatEnabled
                        ? const Color(0xFFDB0C0C)
                        : Colors.grey.shade600,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    "Chat Bengkel",
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: chatEnabled
                          ? const Color(0xFFDB0C0C)
                          : Colors.grey.shade600,
                    ),
                  ),
                  if (!chatEnabled) ...[
                    SizedBox(width: 6.w),
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: ValueListenableBuilder<List<LayananItem>>(
              valueListenable: selectedLayanan,
              builder: (context, list, _) {
                final hasSelected = list.isNotEmpty;

                return ElevatedButton(
                  onPressed: () async {
                    if (!hasSelected) {
                      final tab = DefaultTabController.of(context);
                      if (tab != null) {
                        tab.animateTo(1);
                      } else {
                        _showPickServiceDialog(context);
                      }
                      return;
                    }

                    final result = await Navigator.push<List<LayananItem>>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingSummaryPage(
                          bengkel: bengkel,
                          layananDipilih: List<LayananItem>.from(list),
                        ),
                      ),
                    );

                    if (result != null) {
                      selectedLayanan.value = result;

                      if (result.isEmpty) {
                        final tab = DefaultTabController.of(context);
                        tab.animateTo(1);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD740),
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                  ),
                  child: Text(
                    hasSelected ? "Booking Sekarang" : "Pilih Layanan",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.sp,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

///////////////////////////////////////////////////////////////////////////
/// SLIVER TABBAR
///////////////////////////////////////////////////////////////////////////

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: tabBar);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
