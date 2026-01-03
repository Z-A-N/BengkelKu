// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'package:bengkelku/bengkel/models/bengkel_model.dart';
import 'package:bengkelku/bengkel/bengkel_detail.dart';

class MapsScreen extends StatefulWidget {
  final Bengkel? focusBengkel;
  const MapsScreen({super.key, this.focusBengkel});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  // ===== STYLE (selaras dashboard) =====
  static const Color _red = Color(0xFFDB0C0C);
  static const Color _yellow = Color(0xFFFFD740);
  static const Color _bg = Color(0xFFF5F5F5);
  static const LatLng _fallbackCenter = LatLng(-6.200000, 106.816666);

  // >>> PENTING: enable Directions API + Billing, lalu isi key ini
  static const String _directionsApiKey = "YOUR_DIRECTIONS_API_KEY";

  // ===== Map =====
  final Completer<GoogleMapController> _mapController = Completer();
  bool _hasMovedCamera = false;

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

  // ===== Search & Filter =====
  late final TextEditingController _searchController;
  late final FocusNode _searchFocus;
  String _query = "";
  bool _filterOpenNow = false;
  bool _filterHighRating = false;

  bool get _searchActive => _searchFocus.hasFocus || _query.trim().isNotEmpty;

  // ===== Lokasi =====
  bool _serviceEnabled = false;
  LocationPermission _permission = LocationPermission.denied;
  bool get _locationGranted =>
      _permission == LocationPermission.whileInUse ||
      _permission == LocationPermission.always;

  Position? _myPos;
  String? _locationHint;

  // ===== Sheet extent =====
  // >>> sheet awal lebih naik + tidak bisa ditarik ke bawah (min = initial)
  static const double _sheetInitial = 0.34;
  static const double _sheetMax = 0.53;

  double _sheetExtent = _sheetInitial;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // ===== Selected bengkel =====
  Bengkel? _selected;

  // ===== Route (polyline) =====
  Set<Polyline> _polylines = {};
  bool _loadingRoute = false;
  String? _routeDistance;
  String? _routeDuration;
  String? _routeToId;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocus = FocusNode();

    if (widget.focusBengkel != null) {
      _selected = widget.focusBengkel;
    }

    _searchFocus.addListener(() {
      setState(() {});
      if (_searchFocus.hasFocus) {
        _animateSheetTo(0.52);
      }
    });

    _initLocationFlow();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  // ===== UI helpers =====
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

  // ===== Location flow =====
  Future<void> _initLocationFlow() async {
    _serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_serviceEnabled) {
      if (!mounted) return;
      setState(
        () => _locationHint = "Aktifkan GPS untuk lihat bengkel terdekat.",
      );
      return;
    }

    _permission = await Geolocator.checkPermission();
    if (_permission == LocationPermission.denied) {
      _permission = await Geolocator.requestPermission();
    }

    if (_permission == LocationPermission.denied) {
      if (!mounted) return;
      setState(() => _locationHint = "Izin lokasi ditolak.");
      return;
    }

    if (_permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() => _locationHint = "Izin lokasi diblokir. Buka pengaturan.");
      return;
    }

    if (!mounted) return;
    setState(() => _locationHint = "Lokasi aktif.");

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

  Future<void> _openAppSettings() => Geolocator.openAppSettings();

  Future<void> _onTapMyLocation() async {
    _serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!_serviceEnabled) {
      _showSnack("Aktifkan GPS dulu ya sob.", isError: true);
      await Geolocator.openLocationSettings();
      return;
    }

    if (!_locationGranted) {
      await _initLocationFlow();
      return;
    }

    await _getAndMoveToMyLocation();
  }

  // ===== Distance =====
  double? _distanceMetersTo(Bengkel b) {
    final me = _myPos;
    if (me == null) return null;
    if (b.lat == 0 && b.lng == 0) return null;

    return Geolocator.distanceBetween(me.latitude, me.longitude, b.lat, b.lng);
  }

  String _prettyDistance(Bengkel b) {
    final m = _distanceMetersTo(b);
    if (m == null) return "—";
    if (m < 1000) return "${m.round()} m";
    final km = m / 1000.0;
    return "${km.toStringAsFixed(km < 10 ? 1 : 0)} km";
  }

  // ===== Filter + Sort =====
  List<Bengkel> _applyFilter(List<Bengkel> all) {
    final q = _query.trim().toLowerCase();

    var list = all.where((b) => !(b.lat == 0 && b.lng == 0)).toList();

    if (q.isNotEmpty) {
      list = list.where((b) {
        final name = b.nama.toLowerCase();
        final addr = b.alamat.toLowerCase();
        final desc = b.deskripsi.toLowerCase();
        return name.contains(q) || addr.contains(q) || desc.contains(q);
      }).toList();
    }

    if (_filterOpenNow) list = list.where((b) => b.buka).toList();
    if (_filterHighRating) list = list.where((b) => b.rating >= 4.5).toList();

    if (_myPos != null) {
      list.sort((a, b) {
        final da = _distanceMetersTo(a) ?? double.infinity;
        final db = _distanceMetersTo(b) ?? double.infinity;
        return da.compareTo(db);
      });
    } else {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    }

    return list;
  }

  // ===== Markers =====
  Set<Marker> _buildMarkers(List<Bengkel> list) {
    final markers = <Marker>{};

    for (final b in list) {
      final pos = LatLng(b.lat, b.lng);
      final isSelected = _selected?.id == b.id;

      final hue = isSelected
          ? BitmapDescriptor.hueOrange
          : (b.buka ? BitmapDescriptor.hueRed : BitmapDescriptor.hueRose);

      markers.add(
        Marker(
          markerId: MarkerId(b.id),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          onTap: () async {
            setState(() {
              _selected = b;
              _clearRoute();
            });
            _animateSheetTo(0.52);

            if (_mapController.isCompleted) {
              final c = await _mapController.future;
              await c.animateCamera(CameraUpdate.newLatLng(pos));
            }
          },
        ),
      );
    }

    return markers;
  }

  Future<void> _moveInitialCameraIfNeeded(List<Bengkel> list) async {
    if (_hasMovedCamera) return;
    if (!_mapController.isCompleted) return;
    final c = await _mapController.future;

    final focus = widget.focusBengkel;
    if (focus != null && focus.lat != 0 && focus.lng != 0) {
      _hasMovedCamera = true;
      await c.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(focus.lat, focus.lng), zoom: 15),
        ),
      );
      return;
    }

    if (_locationGranted && _myPos != null) {
      _hasMovedCamera = true;
      await c.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_myPos!.latitude, _myPos!.longitude),
            zoom: 14.5,
          ),
        ),
      );
      return;
    }

    if (list.isNotEmpty) {
      _hasMovedCamera = true;
      await c.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(list.first.lat, list.first.lng),
            zoom: 13,
          ),
        ),
      );
    }
  }

  // ===== Filter bottom sheet =====
  void _openFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) {
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
                        backgroundColor: _red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _filterOpenNow = tempOpenNow;
                          _filterHighRating = tempHighRating;
                          _selected = null;
                          _clearRoute();
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
                        _selected = null;
                        _clearRoute();
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

  // ===== Sheet control =====
  Future<void> _animateSheetTo(double size) async {
    try {
      await _sheetController.animateTo(
        size.clamp(_sheetInitial, _sheetMax),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    } catch (_) {}
  }

  // ===== ROUTE: Directions API =====
  void _clearRoute() {
    _polylines = {};
    _routeDistance = null;
    _routeDuration = null;
    _routeToId = null;
  }

  Future<void> _drawRouteToSelected() async {
    final b = _selected;
    if (b == null) return;

    if (!_locationGranted) {
      _showSnack("Aktifkan izin lokasi dulu untuk buat rute.", isError: true);
      await _initLocationFlow();
      if (!_locationGranted) return;
    }

    if (_myPos == null) {
      await _getAndMoveToMyLocation();
      if (_myPos == null) {
        _showSnack("Lokasi kamu belum kebaca, coba lagi ya.", isError: true);
        return;
      }
    }

    if (_directionsApiKey.trim().isEmpty ||
        _directionsApiKey == "YOUR_DIRECTIONS_API_KEY") {
      _showSnack("Isi _directionsApiKey dulu ya sob.", isError: true);
      return;
    }

    if (_routeToId == b.id && _polylines.isNotEmpty) {
      setState(() => _clearRoute());
      return;
    }

    setState(() => _loadingRoute = true);

    try {
      final origin = "${_myPos!.latitude},${_myPos!.longitude}";
      final dest = "${b.lat},${b.lng}";

      final uri = Uri.parse(
        "https://maps.googleapis.com/maps/api/directions/json"
        "?origin=$origin"
        "&destination=$dest"
        "&mode=driving"
        "&language=id"
        "&key=$_directionsApiKey",
      );

      final res = await http.get(uri);
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if ((data["status"] ?? "") != "OK") {
        final msg =
            (data["error_message"] ?? data["status"] ?? "Gagal") as String;
        throw Exception(msg);
      }

      final routes = (data["routes"] as List);
      if (routes.isEmpty) throw Exception("Rute tidak ditemukan.");

      final route0 = routes.first as Map<String, dynamic>;
      final overview = route0["overview_polyline"] as Map<String, dynamic>;
      final points = (overview["points"] ?? "") as String;

      final legs = (route0["legs"] as List);
      if (legs.isNotEmpty) {
        final leg0 = legs.first as Map<String, dynamic>;
        _routeDistance = (leg0["distance"]?["text"] ?? "") as String;
        _routeDuration = (leg0["duration"]?["text"] ?? "") as String;
      }

      final decoded = _decodePolyline(points);
      if (decoded.isEmpty) throw Exception("Polyline kosong.");

      final polyline = Polyline(
        polylineId: const PolylineId("route"),
        points: decoded,
        width: 6,
        color: _red,
      );

      setState(() {
        _polylines = {polyline};
        _routeToId = b.id;
      });

      final bounds = _boundsFromLatLngList(decoded);
      if (_mapController.isCompleted) {
        final c = await _mapController.future;
        await c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
      }
    } catch (e) {
      _showSnack("Gagal bikin rute: $e", isError: true);
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> poly = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int b;
      int shift = 0;
      int result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      poly.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return poly;
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double minLat = list.first.latitude;
    double maxLat = list.first.latitude;
    double minLng = list.first.longitude;
    double maxLng = list.first.longitude;

    for (final p in list) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLng = min(minLng, p.longitude);
      maxLng = max(maxLng, p.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    // tombol lokasi: dekat sheet awal + ketutup saat sheet naik (karena ditaruh sebelum sheet)
      final screenH = MediaQuery.of(context).size.height;
  
      final double locBtnBottomRaw = (screenH * _sheetExtent) + 10.h;
      final double locBtnBottom = locBtnBottomRaw.clamp(90.h, screenH - 160.h);

    return Scaffold(
      backgroundColor: _bg,
      body: StreamBuilder<List<Bengkel>>(
        stream: _bengkelStream,
        builder: (context, snap) {
          final all = snap.data ?? [];
          final filtered = _applyFilter(all);
          final markers = _buildMarkers(filtered);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (snap.connectionState != ConnectionState.waiting) {
              _moveInitialCameraIfNeeded(filtered);
            }
          });

          return Stack(
            children: [
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: _fallbackCenter,
                    zoom: 11,
                  ),
                  markers: markers,
                  polylines: _polylines,
                  myLocationEnabled: _locationGranted,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                  onTap: (_) => setState(() {
                    _selected = null;
                    _clearRoute();
                  }),
                  onMapCreated: (c) async {
                    if (!_mapController.isCompleted) _mapController.complete(c);
                    await c.setMapStyle(_mapStyle);
                  },
                ),
              ),

              Positioned.fill(
                child: IgnorePointer(
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
              ),

              // TOP UI
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
                  child: Row(
                    children: [
                      _CircleBtn(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _searchFocus.requestFocus(),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            height: (_searchActive ? 56.h : 44.h),
                            padding: EdgeInsets.symmetric(horizontal: 12.w),
                            decoration: _cardDecoration(radius: 24),
                            child: Row(
                              children: [
                                Icon(Icons.search, color: Colors.grey[600]),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: _searchActive
                                      ? TextField(
                                          focusNode: _searchFocus,
                                          controller: _searchController,
                                          onChanged: (v) => setState(() {
                                            _query = v;
                                            _selected = null;
                                            _clearRoute();
                                          }),
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
                                if (_query.trim().isNotEmpty) ...[
                                  InkWell(
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: () {
                                      setState(() {
                                        _query = "";
                                        _searchController.clear();
                                        _selected = null;
                                        _clearRoute();
                                      });
                                      FocusScope.of(context).unfocus();
                                    },
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
                                  color: (_filterOpenNow || _filterHighRating)
                                      ? _red
                                      : Colors.grey[600],
                                  onPressed: _openFilterBottomSheet,
                                  tooltip: "Filter",
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_locationHint != null)
                Positioned(
                  left: 16.w,
                  top: 76.h,
                  child: SafeArea(
                    child: _Badge(
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
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (_permission ==
                              LocationPermission.deniedForever) ...[
                            SizedBox(width: 8.w),
                            GestureDetector(
                              onTap: _openAppSettings,
                              child: Text(
                                "Buka",
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w900,
                                  color: _red,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

              // >>> TOMBOL LOKASI: taruh SEBELUM sheet supaya ketutup saat sheet naik
              Positioned(
                right: 16.w,
                bottom: locBtnBottom,
                child: _CircleBtn(
                  icon: Icons.my_location_rounded,
                  onTap: _onTapMyLocation,
                  accent: true,
                ),
              ),

              // LIST TERDEKAT
              NotificationListener<DraggableScrollableNotification>(
                onNotification: (n) {
                  setState(() => _sheetExtent = n.extent);
                  return false;
                },
                child: DraggableScrollableSheet(
                  controller: _sheetController,
                  initialChildSize: _sheetInitial,
                  minChildSize: _sheetInitial,
                  maxChildSize: _sheetMax,
                  builder: (context, scrollController) {
                    final bool compactMode = _sheetExtent < 0.33;
                    final safeBottom = MediaQuery.of(context).padding.bottom;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(22.r),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.14),
                            blurRadius: 24,
                            offset: const Offset(0, -8),
                          ),
                        ],
                      ),
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.fromLTRB(
                          16.w,
                          10.h,
                          16.w,
                          16.h + safeBottom + 12.h,
                        ),
                        children: [
                          Center(
                            child: Container(
                              width: 40.w,
                              height: 4.h,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _myPos != null
                                      ? "Bengkel terdekat"
                                      : "Rekomendasi bengkel",
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
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
                                  "${filtered.length} hasil",
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (_query.trim().isNotEmpty ||
                                  _filterOpenNow ||
                                  _filterHighRating)
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _query = "";
                                      _searchController.clear();
                                      _filterOpenNow = false;
                                      _filterHighRating = false;
                                      _selected = null;
                                      _clearRoute();
                                    });
                                    FocusScope.of(context).unfocus();
                                  },
                                  child: Text(
                                    "Reset",
                                    style: TextStyle(
                                      color: _red,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          if (_selected != null) ...[
                            SizedBox(height: 10.h),
                            _SelectedCard(
                              bengkel: _selected!,
                              distanceText: _prettyDistance(_selected!),
                              loadingRoute: _loadingRoute,
                              routeDistance: _routeDistance,
                              routeDuration: _routeDuration,
                              routeActive:
                                  _routeToId == _selected!.id &&
                                  _polylines.isNotEmpty,
                              onClose: () => setState(() {
                                _selected = null;
                                _clearRoute();
                              }),
                              onDetail: () {
                                final b = _selected!;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        BengkelDetailPage(bengkel: b),
                                  ),
                                );
                              },
                              onRoute: _drawRouteToSelected,
                            ),
                          ],

                          SizedBox(height: 12.h),

                          if (filtered.isEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 12.h),
                              child: Center(
                                child: Text(
                                  "Tidak ada bengkel yang cocok.\nCoba ubah kata kunci / filter.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                          else if (compactMode) ...[
                            SizedBox(
                              height: 170.h,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: filtered.length.clamp(0, 12).toInt(),
                                separatorBuilder: (_, __) =>
                                    SizedBox(width: 12.w),
                                itemBuilder: (_, i) {
                                  final b = filtered[i];
                                  return _BengkelMiniCard(
                                    bengkel: b,
                                    distanceText: _prettyDistance(b),
                                    onTap: () async {
                                      setState(() {
                                        _selected = b;
                                        _clearRoute();
                                      });
                                      _animateSheetTo(0.52);

                                      if (_mapController.isCompleted) {
                                        final c = await _mapController.future;
                                        await c.animateCamera(
                                          CameraUpdate.newCameraPosition(
                                            CameraPosition(
                                              target: LatLng(b.lat, b.lng),
                                              zoom: 15,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              "Tarik ke atas untuk lihat semua",
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ] else ...[
                            for (final b in filtered) ...[
                              _BengkelListTile(
                                bengkel: b,
                                distanceText: _prettyDistance(b),
                                onTap: () async {
                                  setState(() {
                                    _selected = b;
                                    _clearRoute();
                                  });

                                  if (_mapController.isCompleted) {
                                    final c = await _mapController.future;
                                    await c.animateCamera(
                                      CameraUpdate.newCameraPosition(
                                        CameraPosition(
                                          target: LatLng(b.lat, b.lng),
                                          zoom: 15,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                              SizedBox(height: 10.h),
                            ],
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==========================
// Widgets
// ==========================

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  const _CircleBtn({
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  static const Color _red = Color(0xFFDB0C0C);

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
          child: Icon(icon, size: 20.sp, color: accent ? _red : Colors.black87),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final Widget child;
  const _Badge({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
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
      child: child,
    );
  }
}

class _BengkelMiniCard extends StatelessWidget {
  final Bengkel bengkel;
  final String distanceText;
  final VoidCallback onTap;

  const _BengkelMiniCard({
    required this.bengkel,
    required this.distanceText,
    required this.onTap,
  });

  static const Color _red = Color(0xFFDB0C0C);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: onTap,
        child: Container(
          width: 260.w,
          padding: EdgeInsets.all(12.w),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      bengkel.nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                bengkel.alamat,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Colors.orange,
                    size: 16,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    bengkel.rating.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    distanceText,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: bengkel.buka
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      bengkel.buka ? "Buka" : "Tutup",
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w900,
                        color: bengkel.buka
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFB71C1C),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h), // spacer kecil, tanpa "Tap untuk fokus"
            ],
          ),
        ),
      ),
    );
  }
}

class _BengkelListTile extends StatelessWidget {
  final Bengkel bengkel;
  final String distanceText;
  final VoidCallback onTap;

  const _BengkelListTile({
    required this.bengkel,
    required this.distanceText,
    required this.onTap,
  });

  static const Color _red = Color(0xFFDB0C0C);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46.w,
                height: 46.w,
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
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            bengkel.nama,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          distanceText,
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      bengkel.alamat,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.orange,
                          size: 16,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          bengkel.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: bengkel.buka
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            bengkel.buka ? "Buka" : "Tutup",
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w900,
                              color: bengkel.buka
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
              SizedBox(width: 8.w),
              Icon(Icons.chevron_right, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedCard extends StatelessWidget {
  final Bengkel bengkel;
  final String distanceText;
  final VoidCallback onDetail;
  final VoidCallback onClose;
  final VoidCallback onRoute;

  final bool loadingRoute;
  final bool routeActive;
  final String? routeDistance;
  final String? routeDuration;

  const _SelectedCard({
    required this.bengkel,
    required this.distanceText,
    required this.onDetail,
    required this.onClose,
    required this.onRoute,
    required this.loadingRoute,
    required this.routeActive,
    required this.routeDistance,
    required this.routeDuration,
  });

  static const Color _red = Color(0xFFDB0C0C);
  static const Color _yellow = Color(0xFFFFD740);

  @override
  Widget build(BuildContext context) {
    final hasInfo =
        (routeDistance ?? "").isNotEmpty || (routeDuration ?? "").isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 4.h, color: _yellow),
          Padding(
            padding: EdgeInsets.all(12.w),
            child: Row(
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
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
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bengkel.nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            bengkel.rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Text(
                            distanceText,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      if (hasInfo) ...[
                        SizedBox(height: 6.h),
                        Text(
                          "Estimasi: ${routeDuration ?? "-"} • ${routeDistance ?? "-"}",
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: EdgeInsets.all(6.w),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20.sp,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDetail,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _red, width: 1.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                    ),
                    child: Text(
                      "Detail",
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w900,
                        color: _red,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: loadingRoute ? null : onRoute,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                    ),
                    child: loadingRoute
                        ? SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            routeActive ? "Hapus Rute" : "Rute",
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
        ],
      ),
    );
  }
}
