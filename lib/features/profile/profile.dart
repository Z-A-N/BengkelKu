// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:bengkelku/features/auth/services/auth_service.dart';
import 'package:bengkelku/features/auth/screens/login_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';

class ProfileTab extends StatefulWidget {
  final String name;
  final String email;
  final String? phone;
  final VoidCallback? onLogout;

  const ProfileTab({
    super.key,
    required this.name,
    required this.email,
    this.phone,
    this.onLogout,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _notifOn = true;

  // ========= STATE FOTO PROFIL =========
  final ImagePicker _picker = ImagePicker();
  File? _localPhotoFile;
  bool _pickingImage = false;

  // ========= STATE MEMBER SEJAK =========
  DateTime? _memberSince;
  bool _loadingMember = true;

  // ========= STATE DATA PROFIL (untuk edit) =========
  String? _displayName;
  String? _phone;
  DateTime? _birthDate;
  String? _gender;
  String? _city;
  String? _address;

  @override
  void initState() {
    super.initState();
    _displayName = widget.name;
    _phone = widget.phone;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _loadingMember = false);
      }
      return;
    }

    DateTime? joined;
    String? name = _displayName ?? widget.name;
    String? phone = _phone ?? widget.phone;
    DateTime? birthDate = _birthDate;
    String? gender = _gender;
    String? city = _city;
    String? address = _address;
    bool notifOn = _notifOn;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      final doc = await docRef.get();
      final data = doc.data();

      if (data != null) {
        // createdAt
        final createdAt = data['createdAt'];
        if (createdAt is Timestamp) {
          joined = createdAt.toDate();
        } else if (createdAt is DateTime) {
          joined = createdAt;
        }

        // field-field tambahan (buat kebutuhan Edit Profile)
        name = (data['name'] as String?) ?? name;
        phone = (data['phone'] as String?) ?? phone;
        gender = (data['gender'] as String?) ?? gender;
        city = (data['city'] as String?) ?? city;
        address = (data['address'] as String?) ?? address;

        final bd = data['birthDate'];
        if (bd is Timestamp) {
          birthDate = bd.toDate();
        } else if (bd is DateTime) {
          birthDate = bd;
        }

        final notifEnabled = data['notifEnabled'];
        if (notifEnabled is bool) {
          notifOn = notifEnabled;
        }
      }

      // fallback kalau createdAt kosong
      joined ??= user.metadata.creationTime;
      joined ??= DateTime.now();

      // backfill createdAt kalau belum ada
      if (data == null || data['createdAt'] == null) {
        await docRef.set({"createdAt": joined}, SetOptions(merge: true));
      }
    } catch (_) {
      // kalau Firestore error, minimal ambil dari metadata
      joined ??= user.metadata.creationTime ?? DateTime.now();
    }

    if (!mounted) return;
    setState(() {
      _memberSince = joined;
      _loadingMember = false;
      _displayName = name ?? widget.name;
      _phone = phone ?? widget.phone;
      _birthDate = birthDate;
      _gender = gender;
      _city = city;
      _address = address;
      _notifOn = notifOn;
    });
  }

  String _memberSinceText() {
    if (_loadingMember) return "Member sejak -";
    if (_memberSince == null) return "Member sejak -";

    const bulanIndo = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    final date = _memberSince!;
    final bulan = bulanIndo[date.month - 1];
    return "Member sejak $bulan ${date.year}";
  }

  Future<void> _onChangePhoto() async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);

    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
        ),
        builder: (ctx) => _buildPhotoSourceSheet(ctx),
      );

      if (source == null) return;

      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() {
        _localPhotoFile = File(picked.path);
      });

      // TODO:
      // - Upload ke Firebase Storage
      // - Simpan URL ke Firestore / user.photoURL
      // - Tarik lagi di HomeDashboard kalau mau sinkron
    } finally {
      if (mounted) {
        setState(() => _pickingImage = false);
      }
    }
  }

  Widget _buildPhotoSourceSheet(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 10.h),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text("Pilih dari Galeri"),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text("Ambil Foto"),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            SizedBox(height: 4.h),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          initialName: _displayName ?? widget.name,
          initialEmail: widget.email,
          initialPhone: _phone,
          initialGender: _gender,
          initialBirthDate: _birthDate,
          initialCity: _city,
          initialAddress: _address,
        ),
      ),
    );

    if (!mounted) return;

    // Ambil hasil dari EditProfileScreen dan update tampilan
    if (result is Map<String, dynamic>) {
      setState(() {
        final name = result['name'] as String?;
        final phone = result['phone'] as String?;
        final gender = result['gender'] as String?;
        final birthDate = result['birthDate'] as DateTime?;
        final city = result['city'] as String?;
        final address = result['address'] as String?;

        if (name != null && name.trim().isNotEmpty) {
          _displayName = name.trim();
        }

        if (phone != null && phone.trim().isNotEmpty) {
          _phone = phone.trim();
        }

        if (gender != null && gender.isNotEmpty) {
          _gender = gender;
        }

        if (birthDate != null) {
          _birthDate = birthDate;
        }

        if (city != null && city.trim().isNotEmpty) {
          _city = city.trim();
        }

        if (address != null && address.trim().isNotEmpty) {
          _address = address.trim();
        }
      });
    }
  }

  Future<void> _openChangePassword() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
  }

  Future<void> _updateNotifPreference(bool enabled) async {
    setState(() => _notifOn = enabled);

    final user = AuthService.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'notifEnabled': enabled,
      }, SetOptions(merge: true));
    } catch (_) {
      // kalau gagal simpan, biarkan saja, nggak fatal
    }
  }

  Future<void> _onDeleteAccount() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Akun'),
        content: const Text(
          'Akun dan data terkait (profil, kendaraan, dll) akan dihapus permanen.\n\n'
          'Tindakan ini tidak dapat dibatalkan. Yakin ingin melanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDB0C0C),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final uid = user.uid;

      // Hapus dokumen user di Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      // NOTE: kalau kamu punya subcollection (vehicle, dsb) dan mau dibersihkan,
      // itu perlu penanganan tambahan (Cloud Functions / batch delete).

      // Hapus akun di FirebaseAuth
      await user.delete();

      // Pastikan sudah logout dan kembali ke halaman login
      await AuthService.instance.logout();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Masuk()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'requires-recent-login') {
        message =
            'Demi keamanan, silakan login ulang terlebih dahulu, lalu coba hapus akun lagi.';
      } else {
        message = e.message ?? 'Gagal menghapus akun.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(),
          SizedBox(height: 16.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              children: [
                _buildAccountInfoCard(), // ✅ hanya 3 field
                SizedBox(height: 12.h),
                _buildSettingsCard(),
                SizedBox(height: 12.h),
                _buildHelpCard(),
                SizedBox(height: 20.h),
                _buildLogoutButton(),
                SizedBox(height: 16.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= HEADER KUNING =================

  Widget _buildHeader() {
    final displayName = _displayName ?? widget.name;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: 36.h, bottom: 24.h),
      decoration: const BoxDecoration(
        color: Color(0xFFFFD740),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Text(
            "Profile Saya",
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 16.h),
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                onTap: _onChangePhoto,
                child: CircleAvatar(
                  radius: 40.r,
                  backgroundColor: Colors.white,
                  backgroundImage: _localPhotoFile != null
                      ? FileImage(_localPhotoFile!)
                      : null,
                  child: _localPhotoFile == null
                      ? Text(
                          _initials(displayName),
                          style: TextStyle(
                            fontSize: 26.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFDB0C0C),
                          ),
                        )
                      : null,
                ),
              ),
              GestureDetector(
                onTap: _onChangePhoto,
                child: Container(
                  width: 28.w,
                  height: 28.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDB0C0C),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            displayName,
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4.h),
          Text(
            _memberSinceText(),
            style: TextStyle(fontSize: 12.sp, color: const Color(0xFFDB0C0C)),
          ),
        ],
      ),
    );
  }

  // ================= KARTU INFORMASI AKUN =================

  Widget _buildAccountInfoCard() {
    final displayName = _displayName ?? widget.name;

    return _ProfileCard(
      title: "Informasi Akun",
      trailingIcon: Icons.edit_outlined,
      onTapHeader: _openEditProfile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow("Nama Lengkap", displayName),
          SizedBox(height: 10.h),
          _infoRow("Nomor Hp", _phone ?? "-"),
          SizedBox(height: 10.h),
          _infoRow("Email", widget.email),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11.sp, color: Colors.grey[700]),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ================= KARTU PENGATURAN =================

  Widget _buildSettingsCard() {
    return _ProfileCard(
      title: "Pengaturan Akun",
      child: Column(
        children: [
          // Ubah Password
          _settingRow(
            icon: Icons.lock_outline,
            label: "Ubah Password",
            trailing: const Icon(Icons.chevron_right),
            onTap: _openChangePassword,
          ),
          Divider(height: 18.h),

          // Notifikasi
          _settingRow(
            icon: Icons.notifications_none,
            label: "Notifikasi",
            trailing: Switch(
              value: _notifOn,
              activeThumbColor: const Color(0xFFDB0C0C),
              onChanged: (val) => _updateNotifPreference(val),
            ),
          ),
          Divider(height: 18.h),

          // Hapus Akun
          _settingRow(
            icon: Icons.delete_outline,
            label: "Hapus Akun",
            color: const Color(0xFFDB0C0C),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: _onDeleteAccount,
          ),
        ],
      ),
    );
  }

  Widget _settingRow({
    required IconData icon,
    required String label,
    Widget? trailing,
    Color? color,
    VoidCallback? onTap,
  }) {
    final iconColor = color ?? Colors.black87;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: iconColor,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  // ================= KARTU BANTUAN =================

  Widget _buildHelpCard() {
    return _ProfileCard(
      title: "Bantuan Dan Dukungan",
      child: Column(
        children: [
          _helpRow("Hubungi Layanan Pelanggan"),
          Divider(height: 18.h),
          _helpRow("FAQ"),
          Divider(height: 18.h),
          _helpRow("Syarat & Ketentuan"),
        ],
      ),
    );
  }

  Widget _helpRow(String label) {
    return Row(
      children: [
        const Icon(Icons.chevron_right, color: Colors.transparent),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
          ),
        ),
        const Icon(Icons.chevron_right, color: Colors.grey),
      ],
    );
  }

  // ================= TOMBOL KELUAR =================

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFDB0C0C)),
          foregroundColor: const Color(0xFFDB0C0C),
          padding: EdgeInsets.symmetric(vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.r),
          ),
        ),
        onPressed: widget.onLogout,
        child: Text(
          "Keluar",
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(" ");
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : "P";
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

// ================= WIDGET KARTU REUSABLE =================

class _ProfileCard extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? trailingIcon;
  final VoidCallback? onTapHeader;

  const _ProfileCard({
    required this.title,
    required this.child,
    this.trailingIcon,
    this.onTapHeader,
  });

  @override
  Widget build(BuildContext context) {
    final headerRow = Row(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        if (trailingIcon != null)
          Icon(trailingIcon, size: 18, color: Colors.grey[700]),
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
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
          onTapHeader != null
              ? InkWell(
                  onTap: onTapHeader,
                  borderRadius: BorderRadius.circular(12.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    child: headerRow,
                  ),
                )
              : headerRow,
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }
}
