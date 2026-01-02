// ignore_for_file: unnecessary_underscores, deprecated_member_use, curly_braces_in_flow_control_structures

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'riwayat_detail.dart';

class RiwayatTab extends StatefulWidget {
  const RiwayatTab({super.key});

  @override
  State<RiwayatTab> createState() => _RiwayatTabState();
}

class _RiwayatTabState extends State<RiwayatTab> {
  int _selectedFilter = 0;

  DateTime _toDate(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return DateTime.fromMillisecondsSinceEpoch(0);
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

  DateTime _mergeDateAndJamStart(DateTime tanggal, String jam) {
    try {
      final startPart = jam.split('-').first.trim();
      final parts = startPart.split(':');
      final hh = int.parse(parts[0].trim());
      final mm = int.parse(parts[1].trim());
      return DateTime(tanggal.year, tanggal.month, tanggal.day, hh, mm);
    } catch (_) {
      return tanggal;
    }
  }

  OrderStatus _parseStatus(dynamic raw) {
    final s = (raw ?? "").toString().toLowerCase().trim();

    if (s == "menunggu" || s == "pending" || s == "waiting") {
      return OrderStatus.pending;
    }
    if (s == "proses" ||
        s == "diproses" ||
        s == "process" ||
        s == "onprogress") {
      return OrderStatus.process;
    }
    if (s == "selesai" || s == "done" || s == "finished" || s == "complete") {
      return OrderStatus.done;
    }
    if (s == "batal" || s == "cancelled" || s == "canceled") {
      return OrderStatus.cancelled;
    }
    return OrderStatus.pending;
  }

  String _layananToText(dynamic layanan) {
    if (layanan is List) {
      final names = <String>[];
      for (final it in layanan) {
        if (it is Map) {
          final n = (it["nama"] ?? it["name"] ?? "").toString().trim();
          if (n.isNotEmpty) names.add(n);
        } else if (it is String) {
          final n = it.trim();
          if (n.isNotEmpty) names.add(n);
        }
      }
      if (names.isNotEmpty) return names.join(", ");
    }
    return "-";
  }

  // ✅ RIWAYAT: pastikan label tampil pakai NOMOR POLISI
  // format: "Motor • Honda Vario 125 • R 2412 ZE"
  String _vehicleLabelFromBooking(Map<String, dynamic> data) {
    final jenis = (data["jenisKendaraan"] ?? "").toString().trim();
    final merek = (data["vehicleMerek"] ?? "").toString().trim();
    final model = (data["vehicleModel"] ?? "").toString().trim();
    final nopol = (data["nomorPolisi"] ?? "").toString().trim();

    final brandModel = [
      merek,
      model,
    ].where((e) => e.isNotEmpty).join(" ").trim();

    final parts = <String>[];
    if (jenis.isNotEmpty) parts.add(jenis);
    if (brandModel.isNotEmpty) parts.add(brandModel);
    if (nopol.isNotEmpty) parts.add(nopol);

    if (parts.isNotEmpty) return parts.join(" • ");

    // fallback kalau data lama
    final direct = (data["vehicleLabel"] ?? "").toString().trim();
    return direct.isNotEmpty ? direct : "-";
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 12.h),
            Center(
              child: Text(
                'Riwayat Pemesanan',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(height: 12.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  _buildFilterChip(0, 'Semua'),
                  _buildFilterChip(1, 'Proses'),
                  _buildFilterChip(2, 'Selesai'),
                  _buildFilterChip(3, 'Batal'),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            Expanded(
              child: (user == null)
                  ? Center(
                      child: Text(
                        "Silakan login untuk melihat riwayat.",
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.grey[700],
                        ),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection("bookings")
                          .where("userId", isEqualTo: user.uid)
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
                              "Gagal memuat riwayat.\n${snap.error}",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[700],
                              ),
                            ),
                          );
                        }

                        final docs = (snap.data?.docs ?? []).toList();
                        if (docs.isEmpty) {
                          return Center(
                            child: Text(
                              "Belum ada riwayat.",
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.grey[700],
                              ),
                            ),
                          );
                        }

                        final orders = docs.map((d) {
                          final data = d.data();

                          final bengkelNama = (data["bengkelNama"] ?? "Bengkel")
                              .toString();

                          final vehicleText = _vehicleLabelFromBooking(data);
                          final layananText = _layananToText(data["layanan"]);

                          final tanggal = _toDate(data["tanggal"]);
                          final jam = (data["jam"] ?? "-").toString();

                          final status = _parseStatus(data["status"]);

                          final sortDt = (tanggal.millisecondsSinceEpoch == 0)
                              ? _toDate(data["createdAt"])
                              : _mergeDateAndJamStart(tanggal, jam);

                          return _OrderItem(
                            id: d.id,
                            bengkelNama: bengkelNama,
                            vehicle: vehicleText,
                            layanan: layananText,
                            date: (tanggal.millisecondsSinceEpoch == 0)
                                ? "-"
                                : _fmtDate(tanggal),
                            time: jam.isEmpty ? "-" : jam,
                            status: status,
                            sortKey: sortDt.millisecondsSinceEpoch,
                          );
                        }).toList();

                        orders.sort((a, b) => b.sortKey.compareTo(a.sortKey));

                        final filtered = orders.where((o) {
                          if (_selectedFilter == 0) return true;
                          if (_selectedFilter == 1) {
                            return o.status == OrderStatus.process ||
                                o.status == OrderStatus.pending;
                          }
                          if (_selectedFilter == 2)
                            return o.status == OrderStatus.done;
                          if (_selectedFilter == 3)
                            return o.status == OrderStatus.cancelled;
                          return true;
                        }).toList();

                        return ListView.separated(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => SizedBox(height: 12.h),
                          itemBuilder: (context, index) {
                            return _OrderCard(item: filtered[index]);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final bool isActive = _selectedFilter == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = index),
        child: Container(
          height: 40.h,
          margin: EdgeInsets.only(right: index == 3 ? 0 : 8.w),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFFD740) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isActive
                  ? const Color(0xFFFFD740)
                  : const Color(0xFFE0E0E0),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.black87 : Colors.grey[700],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum OrderStatus { pending, process, done, cancelled }

class _OrderItem {
  final String id;
  final String bengkelNama;
  final String vehicle;
  final String layanan;
  final String date;
  final String time;
  final OrderStatus status;
  final int sortKey;

  _OrderItem({
    required this.id,
    required this.bengkelNama,
    required this.vehicle,
    required this.layanan,
    required this.date,
    required this.time,
    required this.status,
    required this.sortKey,
  });
}

class _OrderCard extends StatelessWidget {
  final _OrderItem item;

  const _OrderCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final statusText = _statusText(item.status);
    final statusBg = _statusBgColor(item.status);
    final statusTextColor = _statusTextColor(item.status);

    return Container(
      width: double.infinity,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.bengkelNama,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      item.vehicle,
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
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: statusTextColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              item.layanan,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[800]),
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: Colors.grey[700],
              ),
              SizedBox(width: 4.w),
              Text(
                item.date,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[800]),
              ),
              SizedBox(width: 18.w),
              Icon(Icons.access_time, size: 14, color: Colors.grey[700]),
              SizedBox(width: 4.w),
              Text(
                item.time,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[800]),
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFEB5757),
                  padding: EdgeInsets.symmetric(
                    horizontal: 18.w,
                    vertical: 6.h,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RiwayatDetailPage(bookingId: item.id),
                    ),
                  );
                },
                child: Text(
                  'Detail',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusText(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return 'Menunggu';
      case OrderStatus.process:
        return 'Proses';
      case OrderStatus.done:
        return 'Selesai';
      case OrderStatus.cancelled:
        return 'Batal';
    }
  }

  Color _statusBgColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
      case OrderStatus.process:
        return const Color(0xFFFFF3CD);
      case OrderStatus.done:
        return const Color(0xFFE8F5E9);
      case OrderStatus.cancelled:
        return const Color(0xFFFFEBEE);
    }
  }

  Color _statusTextColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
      case OrderStatus.process:
        return const Color(0xFFF2994A);
      case OrderStatus.done:
        return const Color(0xFF2E7D32);
      case OrderStatus.cancelled:
        return const Color(0xFFEB5757);
    }
  }
}
