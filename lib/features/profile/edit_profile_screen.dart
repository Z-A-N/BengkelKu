// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:bengkelku/features/auth/services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  final String initialName;
  final String initialEmail;
  final String? initialPhone;
  final String? initialGender; // 'L', 'P', 'other'
  final DateTime? initialBirthDate;
  final String? initialCity;
  final String? initialAddress;

  const EditProfileScreen({
    super.key,
    required this.initialName,
    required this.initialEmail,
    this.initialPhone,
    this.initialGender,
    this.initialBirthDate,
    this.initialCity,
    this.initialAddress,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _birthDateController;

  DateTime? _birthDate;
  String? _gender; // 'L', 'P', 'other'

  // kota dropdown
  static const List<String> _availableCities = ['Purwokerto', 'Purbalingga'];
  String? _city;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
    _addressController = TextEditingController(
      text: widget.initialAddress ?? '',
    );
    _birthDateController = TextEditingController(
      text: widget.initialBirthDate != null
          ? _formatTanggal(widget.initialBirthDate!)
          : '',
    );

    _birthDate = widget.initialBirthDate;
    _gender = widget.initialGender;

    // set kota awal hanya kalau cocok dengan list dropdown
    if (widget.initialCity != null &&
        _availableCities.contains(widget.initialCity)) {
      _city = widget.initialCity;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  // ============== HELPER UI SNACKBAR (SAMA KAYA CHANGE PASSWORD) ==============

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: isError
              ? Colors.red.shade700
              : Colors.green.shade600,
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ==========================================================================

  InputDecoration _inputDecoration({
    required String label,
    IconData? icon,
    IconData? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
      prefixIcon: icon != null ? Icon(icon) : null,
      suffixIcon: suffixIcon != null ? Icon(suffixIcon) : null,
    );
  }

  String _formatTanggal(DateTime d) {
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

    final hari = d.day.toString().padLeft(2, '0');
    final bulan = bulanIndo[d.month - 1];
    final tahun = d.year.toString();
    return "$hari $bulan $tahun";
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 20, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthDateController.text = _formatTanggal(picked);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

    try {
      final user = AuthService.instance.currentUser;
      if (user == null) {
        _showSnackBar('User tidak ditemukan. Silakan login ulang.');
        return;
      }

      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final city = (_city ?? '').trim();
      final address = _addressController.text.trim();

      final updates = <String, dynamic>{'name': name};

      if (phone.isNotEmpty) updates['phone'] = phone;
      if (_gender != null && _gender!.isNotEmpty) {
        updates['gender'] = _gender;
      }
      if (_birthDate != null) {
        updates['birthDate'] = Timestamp.fromDate(_birthDate!);
      }
      if (city.isNotEmpty) updates['city'] = city;
      if (address.isNotEmpty) updates['address'] = address;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(updates, SetOptions(merge: true));

      await user.updateDisplayName(name);

      if (!mounted) return;

      _showSnackBar('Profil berhasil diperbarui', isError: false);

      Navigator.pop(context, {
        'name': name,
        'phone': phone.isNotEmpty ? phone : null,
        'gender': _gender,
        'birthDate': _birthDate,
        'city': city.isNotEmpty ? city : null,
        'address': address.isNotEmpty ? address : null,
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String snackMessage;
      switch (e.code) {
        case 'network-request-failed':
          snackMessage = 'Koneksi internet bermasalah.';
          break;
        default:
          snackMessage = 'Gagal menyimpan profil. Coba lagi.';
      }

      _showSnackBar(snackMessage, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Gagal menyimpan profil. Coba lagi.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Edit Profil',
            style: TextStyle(color: Colors.black),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ====== BAGIAN INFORMASI AKUN ======
                  Text(
                    "Informasi Akun",
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // NAMA
                        TextFormField(
                          controller: _nameController,
                          decoration: _inputDecoration(
                            label: 'Nama Lengkap',
                            icon: Icons.person_outline,
                          ),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return 'Nama wajib diisi';
                            if (t.length < 3) return 'Nama terlalu pendek';
                            return null;
                          },
                        ),
                        SizedBox(height: 14.h),

                        // NOMOR HP
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDecoration(
                            label: 'Nomor HP',
                            icon: Icons.phone_outlined,
                          ),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return 'Nomor HP wajib diisi';
                            if (t.length < 8) return 'Nomor HP terlalu pendek';
                            return null;
                          },
                        ),
                        SizedBox(height: 14.h),

                        // EMAIL (READ ONLY)
                        TextFormField(
                          initialValue: widget.initialEmail,
                          readOnly: true,
                          decoration: _inputDecoration(
                            label: 'Email (tidak dapat diubah)',
                            icon: Icons.email_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // ====== BAGIAN DATA DIRI ======
                  Text(
                    "Data Diri",
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // TANGGAL LAHIR (WAJIB)
                        TextFormField(
                          controller: _birthDateController,
                          readOnly: true,
                          decoration: _inputDecoration(
                            label: 'Tanggal Lahir',
                            icon: Icons.cake_outlined,
                            suffixIcon: Icons.calendar_today_outlined,
                          ).copyWith(hintText: 'Pilih tanggal lahir'),
                          onTap: _pickBirthDate,
                          validator: (_) {
                            if (_birthDate == null) {
                              return 'Tanggal lahir wajib diisi';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 14.h),

                        // JENIS KELAMIN (OPSIONAL)
                        DropdownButtonFormField<String>(
                          value: _gender,
                          decoration: _inputDecoration(
                            label: 'Jenis Kelamin',
                            icon: Icons.wc_outlined,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'L',
                              child: Text('Laki-laki'),
                            ),
                            DropdownMenuItem(
                              value: 'P',
                              child: Text('Perempuan'),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text('Lainnya'),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() => _gender = val);
                          },
                        ),
                        SizedBox(height: 14.h),

                        // KOTA (DROPDOWN)
                        DropdownButtonFormField<String>(
                          value: _city,
                          decoration: _inputDecoration(
                            label: 'Kota',
                            icon: Icons.location_city_outlined,
                          ),
                          items: _availableCities
                              .map(
                                (city) => DropdownMenuItem(
                                  value: city,
                                  child: Text(city),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() => _city = val);
                          },
                        ),
                        SizedBox(height: 14.h),

                        // DETAIL ALAMAT (FORM BIASA, BUKAN TEXT AREA)
                        TextFormField(
                          controller: _addressController,
                          decoration: _inputDecoration(
                            label: 'Detail alamat',
                            icon: Icons.home_outlined,
                          ),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 32.h),

                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDB0C0C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Simpan Perubahan',
                              style: TextStyle(color: Colors.white),
                            ),
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
