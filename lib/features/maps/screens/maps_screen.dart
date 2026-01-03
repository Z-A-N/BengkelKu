// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:bengkelku/bengkel/models/bengkel_model.dart';
import 'package:bengkelku/bengkel/bengkel_detail.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  final Completer<GoogleMapController> _mapController = Completer();

  static const Color _red = Color(0xFFDB0C0C);
  static const LatLng _fallbackCenter = LatLng(
    -6.200000,
    106.816666,
  ); // Jakarta

  bool _hasMovedCamera = false;

  // lokasi user
  bool _serviceEnabled = false;
  LocationPermission _permission = LocationPermission.denied;
  bool get _locationGranted =>
      _permission == LocationPermission.whileInUse ||
      _permission == LocationPermission.always;

  Position? _myPos;
  String? _locationHint; // pesan status kecil (opsional)

  // style biar map lebih clean
  static const String _mapStyle = r'''
  [
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"transit","stylers":[{"visibility":"off"}]},
    {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]}
  ]
  ''';

  Stream<List<Bengkel>> get _bengkelStream {
    return FirebaseFirestore.instance
        .collection('bengkel')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Bengkel.fromDoc(d)).toList());
  }

  @override
  void initState() {
    super.initState();
    _initLocationFlow();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? Colors.red.shade700 : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _initLocationFlow() async {
    // cek service
    _serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_serviceEnabled) {
      setState(() {
        _locationHint = "Aktifkan GPS untuk melihat lokasi kamu.";
      });
      return;
    }

    // cek & request permission
    _permission = await Geolocator.checkPermission();
    if (_permission == LocationPermission.denied) {
      _permission = await Geolocator.requestPermission();
    }

    if (_permission == LocationPermission.denied) {
      setState(() => _locationHint = "Izin lokasi ditolak.");
      return;
    }

    if (_permission == LocationPermission.deniedForever) {
      setState(() => _locationHint = "Izin lokasi diblokir. Buka pengaturan.");
      return;
    }

    setState(() {
      _locationHint = "Lokasi aktif.";
    });

    await _getAndMoveToMyLocation();
  }

  Future<void> _getAndMoveToMyLocation() async {
    if (!_locationGranted) return;

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() => _myPos = pos);

      if (_mapController.isCompleted) {
        final c = await _mapController.future;
        await c.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(pos.latitude, pos.longitude),
              zoom: 14.5,
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationHint = "Gagal mengambil lokasi. Coba lagi.");
    }
  }

  Set<Marker> _buildMarkers(List<Bengkel> list) {
    final markers = <Marker>{};

    for (final b in list) {
      final gp = b.lokasi;

      // skip data invalid
      if (gp.latitude == 0 && gp.longitude == 0) continue;

      final pos = LatLng(gp.latitude, gp.longitude);

      markers.add(
        Marker(
          markerId: MarkerId(b.id),
          position: pos,
          infoWindow: InfoWindow(
            title: b.nama,
            snippet: b.alamat,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BengkelDetailPage(bengkel: b),
                ),
              );
            },
          ),
        ),
      );
    }

    return markers;
  }

  Future<void> _moveToFirstBengkelIfNeeded(List<Bengkel> list) async {
    if (_hasMovedCamera) return;
    if (_locationGranted && _myPos != null) {
      // kalau lokasi user aktif, prioritas ke lokasi user
      _hasMovedCamera = true;
      return;
    }

    final valid = list
        .where((b) => !(b.lokasi.latitude == 0 && b.lokasi.longitude == 0))
        .toList();

    if (valid.isEmpty) return;

    final c = await _mapController.future;
    final first = valid.first;

    _hasMovedCamera = true;

    await c.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(first.lokasi.latitude, first.lokasi.longitude),
          zoom: 13.2,
        ),
      ),
    );
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18.r),
            child: Stack(
              children: [
                // MAP
                StreamBuilder<List<Bengkel>>(
                  stream: _bengkelStream,
                  builder: (context, snapshot) {
                    final list = snapshot.data ?? [];
                    final markers = _buildMarkers(list);

                    if (snapshot.connectionState != ConnectionState.waiting) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _moveToFirstBengkelIfNeeded(list);
                      });
                    }

                    return GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: _fallbackCenter,
                        zoom: 11,
                      ),
                      markers: markers,
                      myLocationEnabled: _locationGranted,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      compassEnabled: false,
                      mapToolbarEnabled: false,
                      onMapCreated: (c) async {
                        if (!_mapController.isCompleted) {
                          _mapController.complete(c);
                        }
                        await c.setMapStyle(_mapStyle);

                        // kalau sudah punya lokasi, langsung fokus
                        if (_locationGranted && _myPos != null) {
                          await c.animateCamera(
                            CameraUpdate.newCameraPosition(
                              CameraPosition(
                                target: LatLng(
                                  _myPos!.latitude,
                                  _myPos!.longitude,
                                ),
                                zoom: 14.5,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),

                // TOP BAR (selaras dashboard)
                Positioned(
                  top: 12.h,
                  left: 12.w,
                  right: 12.w,
                  child: _TopBar(
                    title: "Peta Bengkel Mitra",
                    onBack: () => Navigator.pop(context),
                  ),
                ),

                // BADGE status lokasi
                if (_locationHint != null)
                  Positioned(
                    top: 66.h,
                    left: 12.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _locationGranted
                                ? Icons.my_location
                                : Icons.location_off,
                            size: 16.sp,
                            color: _locationGranted ? _red : Colors.grey[700],
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            _locationHint!,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_permission ==
                              LocationPermission.deniedForever) ...[
                            SizedBox(width: 8.w),
                            GestureDetector(
                              onTap: _openLocationSettings,
                              child: Text(
                                "Buka",
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: _red,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                // BOTTOM CARD info jumlah bengkel
                Positioned(
                  left: 12.w,
                  right: 12.w,
                  bottom: 12.h,
                  child: StreamBuilder<List<Bengkel>>(
                    stream: _bengkelStream,
                    builder: (context, snap) {
                      final count = (snap.data ?? []).length;

                      return Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42.w,
                              height: 42.w,
                              decoration: BoxDecoration(
                                color: _red.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                              child: Icon(
                                Icons.store_mall_directory_rounded,
                                color: _red,
                                size: 22.sp,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "$count Bengkel Mitra",
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    "Tap marker untuk lihat info bengkel",
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                if (!_serviceEnabled) {
                                  _showSnack(
                                    "Aktifkan GPS dulu ya sob.",
                                    isError: true,
                                  );
                                  await Geolocator.openLocationSettings();
                                  return;
                                }
                                if (!_locationGranted) {
                                  await _initLocationFlow();
                                  return;
                                }
                                await _getAndMoveToMyLocation();
                              },
                              child: Text(
                                "Lokasi Saya",
                                style: TextStyle(
                                  color: _red,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _TopBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: EdgeInsets.all(6.w),
              child: Icon(Icons.arrow_back_rounded, size: 20.sp),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
