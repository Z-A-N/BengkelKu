// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bengkelku/bengkel/models/bengkel_model.dart';

@immutable
class BengkelFilters {
  final bool openNow;
  final bool highRating;

  const BengkelFilters({required this.openNow, required this.highRating});

  static const empty = BengkelFilters(openNow: false, highRating: false);

  bool get isActive => openNow || highRating;
}

class BengkelSearchService {
  /// distanceMeters optional:
  /// - kalau ada -> sort by distance ascending
  /// - kalau null -> sort by rating desc
  static List<Bengkel> apply({
    required List<Bengkel> all,
    required String query,
    required BengkelFilters filters,
    double Function(Bengkel b)? distanceMeters,
  }) {
    final q = query.trim().toLowerCase();

    var list = all.where((b) => !(b.lat == 0 && b.lng == 0)).toList();

    if (q.isNotEmpty) {
      list = list.where((b) {
        final name = b.nama.toLowerCase();
        final addr = b.alamat.toLowerCase();
        final desc = b.deskripsi.toLowerCase();
        return name.contains(q) || addr.contains(q) || desc.contains(q);
      }).toList();
    }

    if (filters.openNow) list = list.where((b) => b.buka).toList();
    if (filters.highRating) list = list.where((b) => b.rating >= 4.5).toList();

    if (distanceMeters != null) {
      list.sort((a, b) => distanceMeters(a).compareTo(distanceMeters(b)));
    } else {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    }

    return list;
  }
}

class MapsSearchHeader extends StatelessWidget {
  final VoidCallback onBack;

  final TextEditingController controller;
  final FocusNode focusNode;

  final String query;
  final BengkelFilters filters;

  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;
  final ValueChanged<BengkelFilters> onFiltersChanged;

  const MapsSearchHeader({
    super.key,
    required this.onBack,
    required this.controller,
    required this.focusNode,
    required this.query,
    required this.filters,
    required this.onQueryChanged,
    required this.onClear,
    required this.onFiltersChanged,
  });

  List<BoxShadow> get _softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  BoxDecoration _cardDecoration({double radius = 18}) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius.r),
    boxShadow: _softShadow,
  );

  bool _searchActive() => focusNode.hasFocus || query.trim().isNotEmpty;

  Future<void> _openFilterBottomSheet(BuildContext context) async {
    final res = await showModalBottomSheet<BengkelFilters>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) {
        bool tempOpenNow = filters.openNow;
        bool tempHighRating = filters.highRating;

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
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Buka sekarang"),
                    value: tempOpenNow,
                    onChanged: (val) => setModalState(() => tempOpenNow = val),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Rating 4.5+"),
                    value: tempHighRating,
                    onChanged: (val) =>
                        setModalState(() => tempHighRating = val),
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
                        Navigator.pop(
                          context,
                          BengkelFilters(
                            openNow: tempOpenNow,
                            highRating: tempHighRating,
                          ),
                        );
                      },
                      child: const Text(
                        "Terapkan",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, BengkelFilters.empty);
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

    if (res != null) onFiltersChanged(res);
  }

  @override
  Widget build(BuildContext context) {
    final active = _searchActive();

    return Row(
      children: [
        _CircleBtn(icon: Icons.arrow_back_rounded, onTap: onBack),
        SizedBox(width: 10.w),
        Expanded(
          child: GestureDetector(
            onTap: () => focusNode.requestFocus(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: (active ? 56.h : 44.h),
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              decoration: _cardDecoration(radius: 24),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey[600]),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: active
                        ? TextField(
                            focusNode: focusNode,
                            controller: controller,
                            onChanged: onQueryChanged,
                            onTapOutside: (_) =>
                                FocusScope.of(context).unfocus(),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: "Cari bengkel / alamat",
                              hintStyle: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : Text(
                            "Pencarian",
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[700],
                            ),
                          ),
                  ),
                  if (query.trim().isNotEmpty) ...[
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: onClear,
                      child: Padding(
                        padding: EdgeInsets.all(6.w),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18.sp,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.tune_rounded),
                    color: filters.isActive
                        ? const Color(0xFFDB0C0C)
                        : Colors.grey[600],
                    onPressed: () => _openFilterBottomSheet(context),
                    tooltip: "Filter",
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---- local widget (biar file ini mandiri) ----
class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: 20.sp, color: Colors.black87),
        ),
      ),
    );
  }
}
