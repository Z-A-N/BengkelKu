// ignore_for_file: dead_code, unnecessary_underscores, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bengkelku/features/auth/services/auth_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../bengkel/models/bengkel_model.dart';
import '../../bengkel/bengkel_detail.dart';
import '../profile/profile.dart';
import '../../widgets/navbar.dart';
import '../chat/chat.dart';
import '../riwayat/riwayat.dart';
import '../auth/screens/login_screen.dart';
import '../maps/screens/maps_screen.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  int _selectedIndex = 0;

  static const AssetImage _defaultWorkshopImage = AssetImage(
    'assets/default_bengkel.png',
  );

  User? get _user => AuthService.instance.currentUser;

  String get _displayName {
    final name = _user?.displayName;
    if (name != null && name.trim().isNotEmpty) return name;
    final email = _user?.email ?? "";
    if (email.contains("@")) return email.split("@").first;
    return "Pengguna";
  }

  String get _initials {
    final parts = _displayName.trim().split(" ");
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : "U";
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String? _userPhone;

  /// search
  late final TextEditingController _searchController;
  String _searchQuery = "";

  /// filter
  bool _filterOpenNow = false;
  bool _filterHighRating = false;

  /// Stream bengkel dari Firestore
  Stream<List<Bengkel>> get _bengkelStream {
    return FirebaseFirestore.instance
        .collection('bengkel')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Bengkel.fromDoc(d)).toList());
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = _user;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return;
      final data = doc.data();

      if (!mounted) return;
      setState(() {
        // city sekarang diambil langsung via StreamBuilder di header
        _userPhone = (data?['phone'] as String?)?.trim();
      });
    } catch (_) {
      // boleh diabaikan (misal offline)
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(_defaultWorkshopImage, context);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // buka halaman detail bengkel
  void _openBengkelDetail(Bengkel b) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BengkelDetailPage(bengkel: b)),
    );
  }

  void _openFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) {
        // pakai variabel sementara supaya bisa diubah di dalam bottom sheet
        bool tempOpenNow = _filterOpenNow;
        bool tempHighRating = _filterHighRating;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      margin: EdgeInsets.only(bottom: 12.h),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Text(
                    "Filter bengkel",
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12.h),

                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Buka sekarang"),
                    value: tempOpenNow,
                    onChanged: (val) {
                      setModalState(() => tempOpenNow = val);
                    },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Rating 4.5+"),
                    value: tempHighRating,
                    onChanged: (val) {
                      setModalState(() => tempHighRating = val);
                    },
                  ),

                  SizedBox(height: 8.h),

                  SizedBox(
                    width: double.infinity,
                    height: 44.h,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDB0C0C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _filterOpenNow = tempOpenNow;
                          _filterHighRating = tempHighRating;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "Terapkan",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),

                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filterOpenNow = false;
                        _filterHighRating = false;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text("Reset filter"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomeTab(context),
            _buildRiwayatTab(),
            _buildChatTab(),
            _buildAkunTab(),
          ],
        ),
      ),
      bottomNavigationBar: Navbar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }

  // =====================================================
  //             DIALOG LOGOUT CUSTOM (KAYA GAMBAR)
  // =====================================================

  Future<bool?> _showLogoutDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 0.85.sw,
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    "Keluar akun?",
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // Description
                  Text(
                    "Apakah kamu yakin ingin logout dari akun ini?",
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.black.withOpacity(0.7),
                      height: 1.4,
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // Red button
                  SizedBox(
                    width: double.infinity,
                    height: 46.h,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDB0C0C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                      ),
                      child: Text(
                        "Keluar",
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 10.h),

                  // Cancel text button (abu-abu)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(ctx, false);
                      },
                      child: Text(
                        "Batal",
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  //                     TAB BERANDA
  // =====================================================

  Widget _buildHomeTab(BuildContext context) {
    const double mapHeightFactor = 160;

    final String rawQuery = _searchQuery.trim();
    final String q = rawQuery.toLowerCase();
    final bool isSearching = q.isNotEmpty;

    final bool isPromoSearch = isSearching && q.contains('promo');
    final bool isBengkelSearch = isSearching && !isPromoSearch;

    // judul umum waktu search
    final String searchTitle = isSearching ? 'Hasil pencarian "$rawQuery"' : '';

    // jarak konten dari atas (kuning fleksibel)
    final double contentTop = isSearching
        ? (145)
              .h // cuma tinggi search bar
        : (145 + mapHeightFactor + 24).h; // search bar + map

    return SingleChildScrollView(
      child: Stack(
        children: [
          _buildYellowHeader(isSearching),

          // SEARCH BAR
          Positioned(
            top: 75.h,
            left: 16.w,
            right: 16.w,
            child: _buildSearchBar(),
          ),

          // MAP CARD hanya muncul saat TIDAK searching
          if (!isSearching)
            Positioned(
              top: 140.h,
              left: 16.w,
              right: 16.w,
              child: _buildMapCard(),
            ),

          // KONTEN DI BAWAH
          Padding(
            padding: EdgeInsets.only(top: contentTop, bottom: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================
                //   MODE : TIDAK SEARCHING
                // ==========================
                if (!isSearching) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: _buildMenuGrid(),
                  ),
                  SizedBox(height: 16.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: _buildXpCard(),
                  ),
                  SizedBox(height: 16.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Text(
                      "Ada promo menarik buat kamu nih ~",
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  SizedBox(
                    height: 230.h,
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      scrollDirection: Axis.horizontal,
                      itemCount: 3,
                      separatorBuilder: (_, __) => SizedBox(width: 12.w),
                      itemBuilder: (_, __) => _buildPromoCard(),
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],

                // ==========================
                //   MODE : SEARCH PROMO
                // ==========================
                if (isPromoSearch) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 0),
                    child: Text(
                      searchTitle, // "Hasil pencarian "promo""
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  SizedBox(
                    height: 230.h,
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      scrollDirection: Axis.horizontal,
                      itemCount: 3,
                      separatorBuilder: (_, __) => SizedBox(width: 12.w),
                      itemBuilder: (_, __) => _buildPromoCard(),
                    ),
                  ),
                ],

                // ==========================
                //   MODE : BENGKEL LIST
                // ==========================
                if (!isSearching || isBengkelSearch) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 0),
                    child: Text(
                      isBengkelSearch
                          ? searchTitle
                          : "Rekomendasi bengkel untukmu",
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: StreamBuilder<List<Bengkel>>(
                      stream: _bengkelStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return const Text("Gagal memuat bengkel");
                        }

                        final all = snapshot.data ?? [];

                        if (all.isEmpty) {
                          return const Text("Belum ada bengkel terdaftar");
                        }

                        List<Bengkel> list = all;
                        if (isBengkelSearch) {
                          list = list.where((b) {
                            final name = b.nama.toLowerCase();
                            final desc = b.deskripsi.toLowerCase();
                            return name.contains(q) || desc.contains(q);
                          }).toList();
                        }

                        if (_filterOpenNow) {
                          list = list.where((b) => b.buka).toList();
                        }

                        if (_filterHighRating) {
                          list = list.where((b) => b.rating >= 4.5).toList();
                        }

                        list.sort((a, b) => b.rating.compareTo(a.rating));

                        if (list.isEmpty) {
                          return SizedBox(
                            width: double.infinity,
                            child: Padding(
                              padding: EdgeInsets.only(top: 40.h),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.search_off_rounded,
                                    size: 56,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 12.h),
                                  Text(
                                    "Tidak ada bengkel yang cocok\n dengan pencarian / filter.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildBengkelCompactCard(list[0]),
                                ),
                                if (list.length > 1) ...[
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: _buildBengkelCompactCard(list[1]),
                                  ),
                                ],
                              ],
                            ),
                            if (list.length > 2) ...[
                              SizedBox(height: 16.h),
                              for (int i = 2; i < list.length; i++) ...[
                                _buildBengkelListCard(list[i]),
                                SizedBox(height: 12.h),
                              ],
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  //                    HEADER KUNING
  // =====================================================

  Widget _buildYellowHeader(bool isSearching) {
    final user = _user;
    final double headerHeight = isSearching ? 180.h : 210.h;

    // fallback kalau user belum login
    if (user == null) {
      return Container(
        height: headerHeight,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFFFD740),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        ),
        child: Transform.translate(
          offset: Offset(0, -73.h),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24.r,
                  backgroundColor: Colors.white,
                  child: Text(
                    _initials,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp,
                      color: const Color(0xFFDB0C0C),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Halo", style: TextStyle(fontSize: 13.sp)),
                    Text(
                      _displayName,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.notifications_none),
              ],
            ),
          ),
        ),
      );
    }

    // versi pakai StreamBuilder biar city auto update setelah edit profil
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        String? userCity;

        if (snapshot.hasData && snapshot.data!.data() != null) {
          final data = snapshot.data!.data()!;
          userCity = (data['city'] as String?)?.trim();
        }

        return Container(
          height: headerHeight,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFFFFD740),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: Transform.translate(
            offset: Offset(0, -73.h),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
              child: Row(
                children: [
                  // avatar bisa di-tap -> ke tab akun
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedIndex = 3; // tab Akun
                      });
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: CircleAvatar(
                      radius: 24.r,
                      backgroundColor: Colors.white,
                      child: Text(
                        _initials,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18.sp,
                          color: const Color(0xFFDB0C0C),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Halo", style: TextStyle(fontSize: 13.sp)),
                      Text(
                        _displayName,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (userCity != null && userCity.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14.sp,
                              color: Colors.black.withOpacity(0.6),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              userCity,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.black.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.notifications_none),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  //                     SEARCH BAR
  // =====================================================

  Widget _buildSearchBar() {
    final bool hasActiveFilter = _filterOpenNow || _filterHighRating;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.grey[600]),
          SizedBox(width: 8.w),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              // 👉 Sekarang: tap di luar cuma nutup keyboard,
              // TIDAK menghapus query / mode search
              onTapOutside: (_) {
                FocusScope.of(context).unfocus();
              },
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "Cari bengkel / promo",
                hintStyle: TextStyle(fontSize: 14.sp, color: Colors.grey),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            color: hasActiveFilter ? const Color(0xFFDB0C0C) : Colors.grey[600],
            onPressed: _openFilterBottomSheet,
            tooltip: "Filter",
          ),
        ],
      ),
    );
  }

  // =====================================================
  //                        MAP CARD
  // =====================================================

  Widget _buildMapCard() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MapsScreen()),
        );
      },
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        height: 160.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            StreamBuilder<List<Bengkel>>(
              stream: _bengkelStream,
              builder: (context, snapshot) {
                final list = snapshot.data ?? [];

                // tentuin center
                LatLng center = const LatLng(-6.200000, 106.816666);
                final valid = list
                    .where(
                      (b) =>
                          !(b.lokasi.latitude == 0 && b.lokasi.longitude == 0),
                    )
                    .toList();
                if (valid.isNotEmpty) {
                  center = LatLng(
                    valid.first.lokasi.latitude,
                    valid.first.lokasi.longitude,
                  );
                }

                // marker sedikit aja biar ringan
                final markers = <Marker>{};
                for (final b in valid.take(20)) {
                  markers.add(
                    Marker(
                      markerId: MarkerId(b.id),
                      position: LatLng(b.lokasi.latitude, b.lokasi.longitude),
                    ),
                  );
                }

                return AbsorbPointer(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: center,
                      zoom: 12,
                    ),
                    markers: markers,
                    liteModeEnabled: true, // ✅ preview mode (Android)
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    compassEnabled: false,
                    mapToolbarEnabled: false,
                  ),
                );
              },
            ),

            // overlay biar lebih cakep
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.black.withOpacity(0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Badge jumlah bengkel
            Positioned(
              right: 12.w,
              bottom: 12.h,
              child: StreamBuilder<List<Bengkel>>(
                stream: _bengkelStream,
                builder: (context, snapshot) {
                  final count = (snapshot.data ?? []).length;
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Text(
                      "$count Bengkel Terdaftar",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.sp,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Hint tap
            Positioned(
              left: 12.w,
              bottom: 12.h,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Text(
                  "Tap untuk buka peta",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  //                AKSI CEPAT (VERSI LEBIH KECIL)
  // =====================================================

  Widget _buildMenuGrid() {
    final items = [
      _QuickAction(
        "Service Rutin",
        Icons.build_rounded,
        const Color(0xFF2F80ED),
      ),
      _QuickAction(
        "Cari Bengkel",
        Icons.search_rounded,
        const Color(0xFF27AE60),
      ),
      _QuickAction(
        "Voucher",
        Icons.local_offer_outlined,
        const Color(0xFFF2994A),
      ),
      _QuickAction("Favorit", Icons.favorite_border, const Color(0xFF9B51E0)),
      _QuickAction("Booking", Icons.event_available, const Color(0xFF27AE60)),
      _QuickAction(
        "Darurat",
        Icons.phone_in_talk_outlined,
        const Color(0xFFEB5757),
      ),
      _QuickAction(
        "Rekomendasi",
        Icons.thumb_up_alt_outlined,
        const Color(0xFFF2C94C),
      ),
      _QuickAction("Lainnya", Icons.more_horiz, Colors.grey),
    ];

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: GridView.builder(
        itemCount: items.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 6,
          mainAxisExtent: 80,
        ),
        itemBuilder: (_, index) {
          final item = items[index];
          return Column(
            children: [
              Container(
                width: 46.w,
                height: 46.w,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(item.icon, size: 22.sp, color: item.color),
              ),
              SizedBox(height: 4.h),
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.sp, color: Colors.black87),
              ),
            ],
          );
        },
      ),
    );
  }

  // =====================================================
  //                         PROMO (DENGAN GAMBAR)
  // =====================================================

  Widget _buildPromoCard() {
    return Container(
      width: 260.w,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner gambar promo
            SizedBox(
              height: 110.h,
              width: double.infinity,
              child: Image.asset(
                'assets/promo_banner.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // fallback kalau asset belum ada
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1976D2), Color(0xFF64B5F6)],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        "Banner Promo",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Teks di bawah gambar
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Ada Promo Spesial!",
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    "Diskon hingga 30% untuk servis rutin di bengkel pilihan.",
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey[800]),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Text(
                      "Lihat Detail",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  //                      KARTU XP / EXP
  // =====================================================

  Widget _buildXpCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Center(
              child: Text("😎", style: TextStyle(fontSize: 26.sp)),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "117 XP lagi ada Harta Karun",
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: LinearProgressIndicator(
                    value: 0.6,
                    minHeight: 6.h,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFDB0C0C)),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Icon(Icons.chevron_right, color: Colors.grey[600]),
        ],
      ),
    );
  }

  // =====================================================
  //      CARD REKOMENDASI DARI OBJECT BENGKEL (FIRESTORE)
  // =====================================================

  /// Kartu kecil (compact) untuk 2 rekomendasi di baris atas
  Widget _buildBengkelCompactCard(Bengkel b) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openBengkelDetail(b),
        child: Container(
          height: 210.h,
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
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildWorkshopImage(height: 110.h),
              Padding(
                padding: EdgeInsets.all(10.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "5.8 km",
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      b.nama,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
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
                          "${b.rating.toStringAsFixed(1)} • 300+ rating",
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
            ],
          ),
        ),
      ),
    );
  }

  /// Kartu besar list di bagian bawah
  Widget _buildBengkelListCard(Bengkel b) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openBengkelDetail(b),
        child: Container(
          height: 110.h,
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
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              _buildWorkshopImage(width: 110.w),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(10.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "5.8 km",
                        style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        b.nama,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
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
                            "${b.rating.toStringAsFixed(1)} • Bengkel terpercaya",
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              b.deskripsi,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: b.buka
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              b.buka ? "Buka" : "Tutup",
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: b.buka
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFB71C1C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkshopImage({double? width, double? height}) {
    return SizedBox(
      width: width,
      height: height,
      child: Image(
        image: _defaultWorkshopImage,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          // fallback aman kalau asset belum ketemu
          return Container(
            color: Colors.grey.shade200,
            child: const Icon(Icons.car_repair, size: 40, color: Colors.grey),
          );
        },
      ),
    );
  }

  // =====================================================
  //              TAB RIWAYAT, CHAT, AKUN
  // =====================================================

  Widget _buildRiwayatTab() {
    return const RiwayatTab();
  }

  Widget _buildChatTab() {
    return const ChatTab();
  }

  Widget _buildAkunTab() {
    return ProfileTab(
      name: _displayName,
      email: _user?.email ?? "-",
      phone: _userPhone, // sekarang diisi dari Firestore
      onLogout: () async {
        final confirm = await _showLogoutDialog();
        if (confirm != true) return;

        // Panggil AuthService, biar Google/Facebook juga ke-logout kalau ada
        await AuthService.instance.logout();

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const Masuk()),
          (route) => false,
        );
      },
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  const _QuickAction(this.label, this.icon, this.color);
}
