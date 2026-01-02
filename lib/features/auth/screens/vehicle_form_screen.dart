// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bengkelku/widgets/ornamen_Lingkaran.dart';
import 'package:bengkelku/features/auth/services/auth_service.dart';
import '../../home/home_dashboard.dart';

// =======================================================
// Uppercase formatter untuk Nomor Polisi
// =======================================================
class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 1. Uppercase & buang semua spasi
    String raw = newValue.text.toUpperCase().replaceAll(RegExp(r'\s+'), '');

    // Kosong? langsung balik aja
    if (raw.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // 2. Pisahin jadi: huruf depan, angka, huruf belakang
    String lettersPrefix = '';
    String numbers = '';
    String lettersSuffix = '';

    int stage = 0; // 0 = prefix huruf, 1 = angka, 2 = suffix huruf

    for (int i = 0; i < raw.length; i++) {
      final c = raw[i];

      final isLetter = RegExp(r'[A-Z]').hasMatch(c);
      final isDigit = RegExp(r'[0-9]').hasMatch(c);

      if (stage == 0) {
        if (isLetter) {
          lettersPrefix += c;
        } else if (isDigit) {
          stage = 1;
          numbers += c;
        }
      } else if (stage == 1) {
        if (isDigit) {
          numbers += c;
        } else if (isLetter) {
          stage = 2;
          lettersSuffix += c;
        }
      } else {
        // stage == 2
        if (isLetter) {
          lettersSuffix += c;
        }
      }
    }

    // 3. Batasi sesuai format plat Indonesia
    if (lettersPrefix.length > 2) {
      lettersPrefix = lettersPrefix.substring(0, 2);
    }
    if (numbers.length > 4) {
      numbers = numbers.substring(0, 4);
    }
    if (lettersSuffix.length > 3) {
      lettersSuffix = lettersSuffix.substring(0, 3);
    }

    // 4. Susun ulang dengan spasi otomatis
    String formatted = lettersPrefix;

    if (numbers.isNotEmpty) {
      if (formatted.isNotEmpty) formatted += ' ';
      formatted += numbers;
    }

    if (lettersSuffix.isNotEmpty) {
      if (formatted.isNotEmpty) formatted += ' ';
      formatted += lettersSuffix;
    }

    // 5. Cursor selalu di akhir teks (biar simpel)
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// =======================================================
// Dropdown Kurus Elegan (Floating Label)
// =======================================================
class SlimDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final IconData? icon;
  final Function(String?) onChanged;
  final String? Function(String?)? validator;

  const SlimDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField(
      value: value,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: Color(0xFFDB0C0C), width: 1.5),
        ),
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

// =======================================================
// MAIN SCREEN
// =======================================================
class VehicleFormScreen extends StatefulWidget {
  const VehicleFormScreen({super.key});

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  String jenisKendaraan = "Motor";
  String? merek;
  String? model;
  String? tahun;

  final nomorPolisi = TextEditingController();
  final kilometer = TextEditingController();

  bool loading = false;

  late AnimationController anim;
  late Animation<double> fade;
  late Animation<Offset> slide;

  final modelMotor = {
    "Honda": ["Beat", "Vario 125", "PCX", "Scoopy"],
    "Yamaha": ["NMax", "Aerox", "Fino", "Mio"],
    "Suzuki": ["Nex II", "Address", "Satria F150"],
  };

  final modelMobil = {
    "Toyota": ["Avanza", "Rush", "Agya", "Yaris"],
    "Daihatsu": ["Xenia", "Ayla", "Terios", "Sigra"],
    "Honda": ["Brio", "HR-V", "Jazz", "Civic"],
  };

  // Ikon dinamis
  IconData getVehicleIcon() {
    return jenisKendaraan == "Motor"
        ? Icons.motorcycle_rounded
        : Icons.directions_car_rounded;
  }

  @override
  void initState() {
    super.initState();

    anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    fade = CurvedAnimation(parent: anim, curve: Curves.easeInOut);
    slide = Tween<Offset>(
      begin: const Offset(0, 0.20),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));

    anim.forward();
  }

  @override
  void dispose() {
    anim.dispose();
    nomorPolisi.dispose();
    kilometer.dispose();
    super.dispose();
  }

  // =======================================================
  // SNACKBAR GLOBAL
  // =======================================================
  void _showSnack(String message, {bool success = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: success
              ? const Color(0xFF27AE60)
              : Colors.red.shade700,
          content: Text(message),
        ),
      );
  }

  // =======================================================
  // SIMPAN DATA KENDARAAN
  // =======================================================
  Future<void> simpanData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showSnack("Sesi habis, silakan login kembali.");
        Navigator.pop(context);
        return;
      }

      await AuthService.instance.saveVehicleData(
        uid: user.uid,
        jenis: jenisKendaraan,
        nomorPolisi: nomorPolisi.text.trim(),
        merek: merek,
        model: model,
        tahun: tahun,
        km: kilometer.text.trim().isEmpty ? null : kilometer.text.trim(),
      );

      _showSnack("Data kendaraan berhasil disimpan!", success: true);

      // Setelah simpan → ke dashboard
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeDashboard()),
        (route) => false,
      );
    } catch (e) {
      _showSnack("Gagal menyimpan data. Coba lagi.");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  InputDecoration _input(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: Color(0xFFDB0C0C), width: 1.5),
      ),
    );
  }

  // =======================================================
  // UI
  // =======================================================
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              const OrnamenSetengahLingkaranAtas(),

              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 520.w),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: 28.w,
                      vertical: 24.h,
                    ),
                    child: FadeTransition(
                      opacity: fade,
                      child: SlideTransition(
                        position: slide,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 0.05.sh),

                            Text(
                              "Isi Data\nKendaraan Anda",
                              style: TextStyle(
                                fontSize: 28.sp,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),

                            SizedBox(height: 24.h),

                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  SlimDropdown(
                                    label: "Jenis Kendaraan",
                                    value: jenisKendaraan,
                                    items: const ["Motor", "Mobil"],
                                    icon: getVehicleIcon(),
                                    onChanged: (v) {
                                      setState(() {
                                        jenisKendaraan = v!;
                                        merek = null;
                                        model = null;
                                      });
                                    },
                                  ),
                                  SizedBox(height: 20.h),

                                  TextFormField(
                                    controller: nomorPolisi,
                                    inputFormatters: const [
                                      UpperCaseTextFormatter(),
                                    ],
                                    decoration: _input("Nomor Polisi"),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return "Wajib diisi";
                                      }

                                      final reg = RegExp(
                                        r'^[A-Z]{1,2}\s?[0-9]{1,4}\s?[A-Z]{1,3}$',
                                      );

                                      if (!reg.hasMatch(v)) {
                                        return "Format tidak valid (ex: B 1234 CD)";
                                      }

                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 20.h),

                                  SlimDropdown(
                                    label: "Merek",
                                    value: merek,
                                    items:
                                        (jenisKendaraan == "Motor"
                                                ? modelMotor.keys
                                                : modelMobil.keys)
                                            .toList(),
                                    onChanged: (v) {
                                      setState(() {
                                        merek = v;
                                        model = null;
                                      });
                                    },
                                    validator: (v) =>
                                        v == null ? "Pilih merek" : null,
                                  ),
                                  SizedBox(height: 20.h),

                                  SlimDropdown(
                                    label: "Model",
                                    value: model,
                                    items: merek == null
                                        ? []
                                        : (jenisKendaraan == "Motor"
                                              ? modelMotor[merek]!
                                              : modelMobil[merek]!),
                                    onChanged: (v) => setState(() => model = v),
                                    validator: (v) =>
                                        v == null ? "Pilih model" : null,
                                  ),
                                  SizedBox(height: 20.h),

                                  SlimDropdown(
                                    label: "Tahun",
                                    value: tahun,
                                    items: List.generate(
                                      16,
                                      (i) => (2010 + i).toString(),
                                    ),
                                    onChanged: (v) => setState(() => tahun = v),
                                    validator: (v) =>
                                        v == null ? "Pilih tahun" : null,
                                  ),
                                  SizedBox(height: 20.h),

                                  TextFormField(
                                    controller: kilometer,
                                    keyboardType: TextInputType.number,
                                    decoration: _input(
                                      "Kilometer (opsional)",
                                      icon: Icons.speed_rounded,
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return null;
                                      if (int.tryParse(v) == null) {
                                        return "Masukkan angka valid";
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 30.h),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 50.h,
                                    child: ElevatedButton(
                                      onPressed: loading ? null : simpanData,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFDB0C0C,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12.r,
                                          ),
                                        ),
                                      ),
                                      child: loading
                                          ? const CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            )
                                          : const Text(
                                              "Simpan Data",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
}
