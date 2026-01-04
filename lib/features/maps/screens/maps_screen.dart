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
import 'package:bengkelku/features/maps/services/search_section.dart';

class MapsScreen extends StatefulWidget {
  final Bengkel? focusBengkel;
  const MapsScreen({super.key, this.focusBengkel});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> with WidgetsBindingObserver {
  // ===== THEME (modern, tetap kuning-merah) =====
  static const Color _red = Color(0xFFDB0C0C);
  static const Color _yellow = Color(0xFFFFD740);
  static const Color _yellowSoft = Color(0xFFFFF3CD);
  static const Color _bg = Color(0xFFF6F7F9);
  static const LatLng _fallbackCenter = LatLng(-6.200000, 106.816666);

  static final Color _redLine = _red.withOpacity(0.18);

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

  // ===== Lokasi =====
  bool _serviceEnabled = false;
  LocationPermission _permission = LocationPermission.denied;

  bool get _locationGranted =>
      _permission == LocationPermission.whileInUse ||
      _permission == LocationPermission.always;

  Position? _myPos;

  // ===== Bottom panel (snap) =====
  static const double _sheetInitial = 0.38;
  static const double _sheetMid = 0.45;
  static const double _sheetMax = 0.55;

  double _sheetExtent = _sheetInitial;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  Timer? _snapTimer;
  bool _snapping = false;

  late final PageController _carouselController;

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
    WidgetsBinding.instance.addObserver(this);

    _searchController = TextEditingController();
    _searchFocus = FocusNode();
    _carouselController = PageController(viewportFraction: 0.90);

    if (widget.focusBengkel != null) {
      _selected = widget.focusBengkel;
    }

    _searchFocus.addListener(() {
      setState(() {});
      if (_searchFocus.hasFocus) {
        _animateSheetTo(_sheetMid);
      }
    });

    // ✅ hanya cek status, TANPA request permission (izin sudah diminta di onboarding)
    _syncLocationStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _snapTimer?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _sheetController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncLocationStatus();
    }
  }

  // ✅ Cek status lokasi TANPA request permission
  Future<void> _syncLocationStatus() async {
    _serviceEnabled = await Geolocator.isLocationServiceEnabled();
    _permission = await Geolocator.checkPermission();

    if (!_locationGranted || !_serviceEnabled) return;

    await _getAndMoveToMyLocation();
  }

  // ===== Location flow (REQUEST) =====
  Future<void> _initLocationFlow() async {
    _serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_serviceEnabled) return;

    _permission = await Geolocator.checkPermission();
    if (_permission == LocationPermission.denied) {
      _permission = await Geolocator.requestPermission(); // popup OS
    }

    if (!_locationGranted) return;

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
      // silent
    }
  }

  Future<void> _onTapMyLocation() async {
    _serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_serviceEnabled) {
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
            final idx = list.indexWhere((x) => x.id == b.id);

            setState(() {
              _selected = b;
              _clearRoute();
            });

            if (_carouselController.hasClients && idx >= 0) {
              _carouselController.animateToPage(
                idx,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
              );
            }

            _animateSheetTo(_sheetMid);

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

  // ===== Snap helper (lebih smooth, ga maksa) =====
  void _scheduleSnap() {
    if (_snapping) return;
    _snapTimer?.cancel();
    _snapTimer = Timer(const Duration(milliseconds: 140), () async {
      if (!mounted) return;
      if (!_sheetController.isAttached) return;

      final target = _snapTarget(_sheetExtent);

      // ✅ threshold lebih longgar biar ga “nempel robot”
      if ((target - _sheetExtent).abs() < 0.03) return;

      _snapping = true;
      try {
        await _sheetController.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      } catch (_) {
        // ignore
      } finally {
        _snapping = false;
      }
    });
  }

  double _snapTarget(double v) {
    final a = (_sheetInitial + _sheetMid) / 2;
    final b = (_sheetMid + _sheetMax) / 2;

    if (v < a) return _sheetInitial;
    if (v < b) return _sheetMid;
    return _sheetMax;
  }

  Future<void> _animateSheetTo(double size) async {
    try {
      await _sheetController.animateTo(
        size.clamp(_sheetInitial, _sheetMax),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    } catch (_) {}
  }

  // ===== ROUTE =====
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
      await _initLocationFlow();
      if (!_locationGranted) return;
    }

    if (_myPos == null) {
      await _getAndMoveToMyLocation();
      if (_myPos == null) return;
    }

    if (_directionsApiKey.trim().isEmpty ||
        _directionsApiKey == "YOUR_DIRECTIONS_API_KEY") {
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
        throw Exception((data["error_message"] ?? data["status"] ?? "Gagal"));
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

      _animateSheetTo(_sheetMax);

      final bounds = _boundsFromLatLngList(decoded);
      if (_mapController.isCompleted) {
        final c = await _mapController.future;
        await c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
      }
    } catch (_) {
      // silent
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

  // ===== CTA actions =====
  void _goBooking(Bengkel b) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BengkelDetailPage(bengkel: b)),
    );
  }

  void _goEmergency(Bengkel b) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BengkelDetailPage(bengkel: b)),
    );
  }

  // ===== UI (Google Maps style: map mengecil saat sheet naik) =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenH = constraints.maxHeight;

          return StreamBuilder<List<Bengkel>>(
            stream: _bengkelStream,
            builder: (context, snap) {
              final all = snap.data ?? [];

              final filtered = BengkelSearchService.apply(
                all: all,
                query: _query,
                filters: BengkelFilters(
                  openNow: _filterOpenNow,
                  highRating: _filterHighRating,
                ),
                distanceMeters: _myPos != null
                    ? (b) => _distanceMetersTo(b) ?? double.infinity
                    : null,
              );

              // Auto select pertama
              if (filtered.isNotEmpty) {
                final selIdx = _selected == null
                    ? -1
                    : filtered.indexWhere((x) => x.id == _selected!.id);

                if (_selected == null || selIdx == -1) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() {
                      _selected = filtered.first;
                      _clearRoute();
                    });
                    if (_carouselController.hasClients) {
                      _carouselController.jumpToPage(0);
                    }
                  });
                } else {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    if (!_carouselController.hasClients) return;
                    final current = (_carouselController.page ?? 0).round();
                    if (current != selIdx)
                      _carouselController.jumpToPage(selIdx);
                  });
                }
              }

              final markers = _buildMarkers(filtered);

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (snap.connectionState != ConnectionState.waiting) {
                  _moveInitialCameraIfNeeded(filtered);
                }
              });

              // ✅ sheet height dalam pixel → buat “map mengecil”
              final sheetPx = (screenH * _sheetExtent).clamp(
                screenH * _sheetInitial,
                screenH * _sheetMax,
              );

              // ✅ mode carousel vs detail
              final bool showCarousel = _sheetExtent < (_sheetMid - 0.015);

              return Stack(
                children: [
                  // =========================
                  // MAP AREA (MENGECIL)
                  // =========================
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: sheetPx, // kuncinya!
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(22.r),
                      ),
                      child: Stack(
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
                                if (!_mapController.isCompleted) {
                                  _mapController.complete(c);
                                }
                                await c.setMapStyle(_mapStyle);
                              },
                            ),
                          ),

                          // overlay gradient (soft)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.center,
                                    colors: [
                                      Colors.black.withOpacity(0.16),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // search header (di map area)
                          SafeArea(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
                              child: MapsSearchHeader(
                                onBack: () => Navigator.pop(context),
                                controller: _searchController,
                                focusNode: _searchFocus,
                                query: _query,
                                filters: BengkelFilters(
                                  openNow: _filterOpenNow,
                                  highRating: _filterHighRating,
                                ),
                                onQueryChanged: (v) => setState(() {
                                  _query = v;
                                  _selected = null;
                                  _clearRoute();
                                }),
                                onClear: () {
                                  setState(() {
                                    _query = "";
                                    _searchController.clear();
                                    _selected = null;
                                    _clearRoute();
                                  });
                                  FocusScope.of(context).unfocus();
                                },
                                onFiltersChanged: (f) => setState(() {
                                  _filterOpenNow = f.openNow;
                                  _filterHighRating = f.highRating;
                                  _selected = null;
                                  _clearRoute();
                                }),
                              ),
                            ),
                          ),

                          // tombol lokasi (nempel di bawah map area)
                          Positioned(
                            right: 16.w,
                            bottom: 16.h,
                            child: _CircleBtn(
                              icon: Icons.my_location_rounded,
                              onTap: _onTapMyLocation,
                              accent: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // =========================
                  // BOTTOM SHEET
                  // =========================
                  Positioned.fill(
                    child: NotificationListener<DraggableScrollableNotification>(
                      onNotification: (n) {
                        // update extent → map ikut resize
                        setState(() => _sheetExtent = n.extent);
                        if (!_snapping) _scheduleSnap();
                        return false;
                      },
                      child: DraggableScrollableSheet(
                        controller: _sheetController,
                        initialChildSize: _sheetInitial,
                        minChildSize: _sheetInitial,
                        maxChildSize: _sheetMax,
                        builder: (context, scrollController) {
                          final safeBottom = MediaQuery.of(
                            context,
                          ).padding.bottom;
                          final selected = _selected;

                          return ClipRRect(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(22.r),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(22.r),
                                ),
                                border: Border(
                                  top: BorderSide(color: _redLine, width: 1),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.10),
                                    blurRadius: 22,
                                    offset: const Offset(0, -10),
                                  ),
                                ],
                              ),
                              child: ListView(
                                controller: scrollController,
                                padding: EdgeInsets.fromLTRB(
                                  0,
                                  10.h,
                                  0,
                                  16.h + safeBottom + 10.h,
                                ),
                                children: [
                                  // handle row + chevron down (ketika detail mode)
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16.w,
                                    ),
                                    child: Row(
                                      children: [
                                        const Spacer(),
                                        Container(
                                          width: 44.w,
                                          height: 4.h,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.10,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        AnimatedOpacity(
                                          duration: const Duration(
                                            milliseconds: 160,
                                          ),
                                          opacity: showCarousel ? 0.0 : 1.0,
                                          child: IgnorePointer(
                                            ignoring: showCarousel,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              onTap: () => _animateSheetTo(
                                                _sheetInitial,
                                              ),
                                              child: Padding(
                                                padding: EdgeInsets.all(6.w),
                                                child: Icon(
                                                  Icons
                                                      .keyboard_arrow_down_rounded,
                                                  size: 22.sp,
                                                  color: Colors.grey[850],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 10.h),

                                  // header (hanya saat carousel)
                                  AnimatedCrossFade(
                                    duration: const Duration(milliseconds: 180),
                                    crossFadeState: showCarousel
                                        ? CrossFadeState.showFirst
                                        : CrossFadeState.showSecond,
                                    firstChild: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16.w,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _myPos != null
                                                  ? "Bengkel terdekat"
                                                  : "Rekomendasi bengkel",
                                              style: TextStyle(
                                                fontSize: 15.sp,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 10.w,
                                              vertical: 6.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _yellowSoft.withOpacity(
                                                0.75,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: Colors.black.withOpacity(
                                                  0.06,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              "${filtered.length} hasil",
                                              style: TextStyle(
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    secondChild: const SizedBox.shrink(),
                                  ),
                                  SizedBox(height: showCarousel ? 10.h : 6.h),

                                  if (filtered.isEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(top: 6.h),
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
                                  else
                                    AnimatedCrossFade(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      crossFadeState: showCarousel
                                          ? CrossFadeState.showFirst
                                          : CrossFadeState.showSecond,
                                      firstChild: Column(
                                        children: [
                                          SizedBox(
                                            height: 156.h,
                                            child: PageView.builder(
                                              controller: _carouselController,
                                              itemCount: filtered.length,
                                              onPageChanged: (i) async {
                                                final b = filtered[i];
                                                setState(() {
                                                  _selected = b;
                                                  _clearRoute();
                                                });

                                                if (_mapController
                                                    .isCompleted) {
                                                  final c = await _mapController
                                                      .future;
                                                  await c.animateCamera(
                                                    CameraUpdate.newCameraPosition(
                                                      CameraPosition(
                                                        target: LatLng(
                                                          b.lat,
                                                          b.lng,
                                                        ),
                                                        zoom: 15,
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                              itemBuilder: (context, i) {
                                                final b = filtered[i];
                                                final isActive =
                                                    selected?.id == b.id;

                                                return Padding(
                                                  padding: EdgeInsets.only(
                                                    left: i == 0 ? 16.w : 8.w,
                                                    right:
                                                        i == filtered.length - 1
                                                        ? 16.w
                                                        : 8.w,
                                                  ),
                                                  child: _BengkelCarouselCard(
                                                    bengkel: b,
                                                    distanceText:
                                                        _prettyDistance(b),
                                                    active: isActive,
                                                    onTap: () async {
                                                      setState(() {
                                                        _selected = b;
                                                        _clearRoute();
                                                      });
                                                      _animateSheetTo(
                                                        _sheetMid,
                                                      );

                                                      if (_mapController
                                                          .isCompleted) {
                                                        final c =
                                                            await _mapController
                                                                .future;
                                                        await c.animateCamera(
                                                          CameraUpdate.newCameraPosition(
                                                            CameraPosition(
                                                              target: LatLng(
                                                                b.lat,
                                                                b.lng,
                                                              ),
                                                              zoom: 15,
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.fromLTRB(
                                              16.w,
                                              8.h,
                                              16.w,
                                              0,
                                            ),
                                            child: Text(
                                              "Geser samping untuk pilih • Tarik ke atas untuk detail",
                                              style: TextStyle(
                                                fontSize: 11.sp,
                                                color: Colors.grey[700],
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: 8.h),
                                        ],
                                      ),
                                      secondChild: Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          16.w,
                                          4.h,
                                          16.w,
                                          0,
                                        ),
                                        child: selected == null
                                            ? const SizedBox.shrink()
                                            : Column(
                                                children: [
                                                  _BengkelDetailSection(
                                                    bengkel: selected,
                                                    distanceText:
                                                        _prettyDistance(
                                                          selected,
                                                        ),
                                                    loadingRoute: _loadingRoute,
                                                    routeDistance:
                                                        _routeDistance,
                                                    routeDuration:
                                                        _routeDuration,
                                                    routeActive:
                                                        _routeToId ==
                                                            selected.id &&
                                                        _polylines.isNotEmpty,
                                                    onBooking: () =>
                                                        _goBooking(selected),
                                                    onEmergency: () =>
                                                        _goEmergency(selected),
                                                    onDirections:
                                                        _drawRouteToSelected,
                                                  ),
                                                  SizedBox(height: 8.h),
                                                  Text(
                                                    "Tarik ke bawah untuk ganti bengkel",
                                                    style: TextStyle(
                                                      fontSize: 11.sp,
                                                      color: Colors.grey[700],
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
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
  static const Color _yellow = Color(0xFFFFD740);

  @override
  Widget build(BuildContext context) {
    final ring = accent ? _yellow.withOpacity(0.92) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          padding: EdgeInsets.all(2.w),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ring,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: accent
                    ? _red.withOpacity(0.18)
                    : Colors.black.withOpacity(0.06),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 20.sp,
              color: accent ? _red : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

class _BengkelCarouselCard extends StatelessWidget {
  final Bengkel bengkel;
  final String distanceText;
  final bool active;
  final VoidCallback onTap;

  const _BengkelCarouselCard({
    required this.bengkel,
    required this.distanceText,
    required this.active,
    required this.onTap,
  });

  static const Color _red = Color(0xFFDB0C0C);
  static const Color _yellow = Color(0xFFFFD740);
  static const Color _yellowSoft = Color(0xFFFFF3CD);

  @override
  Widget build(BuildContext context) {
    final borderColor = active
        ? _red.withOpacity(0.18)
        : Colors.black.withOpacity(0.06);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: onTap,
        child: AnimatedScale(
          scale: active ? 1.0 : 0.992,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_yellowSoft.withOpacity(0.60), Colors.white],
              ),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(active ? 0.08 : 0.05),
                  blurRadius: active ? 14 : 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14.r),
                        color: _yellow.withOpacity(0.55),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.06),
                        ),
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
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(
                      Icons.place_rounded,
                      size: 14.sp,
                      color: Colors.grey[700],
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        bengkel.alamat,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),

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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Icon(
                      Icons.near_me_rounded,
                      size: 14.sp,
                      color: Colors.grey[700],
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      distanceText,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[800],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 9.w,
                        vertical: 4.5.h,
                      ),
                      decoration: BoxDecoration(
                        color: bengkel.buka
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: bengkel.buka
                              ? const Color(0xFF2E7D32).withOpacity(0.18)
                              : const Color(0xFFB71C1C).withOpacity(0.18),
                        ),
                      ),
                      child: Text(
                        bengkel.buka ? "Buka" : "Tutup",
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                          color: bengkel.buka
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFB71C1C),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BengkelDetailSection extends StatelessWidget {
  final Bengkel bengkel;
  final String distanceText;

  final bool loadingRoute;
  final bool routeActive;
  final String? routeDistance;
  final String? routeDuration;

  final VoidCallback onBooking;
  final VoidCallback onEmergency;
  final VoidCallback onDirections;

  const _BengkelDetailSection({
    required this.bengkel,
    required this.distanceText,
    required this.loadingRoute,
    required this.routeActive,
    required this.routeDistance,
    required this.routeDuration,
    required this.onBooking,
    required this.onEmergency,
    required this.onDirections,
  });

  static const Color _red = Color(0xFFDB0C0C);
  static const Color _yellow = Color(0xFFFFD740);

  @override
  Widget build(BuildContext context) {
    final hasRouteInfo =
        (routeDistance ?? "").isNotEmpty || (routeDuration ?? "").isNotEmpty;

    Widget statusChip() {
      final isOpen = bengkel.buka;
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isOpen ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isOpen
                ? const Color(0xFF2E7D32).withOpacity(0.18)
                : const Color(0xFFB71C1C).withOpacity(0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOpen ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 16.sp,
              color: isOpen ? const Color(0xFF2E7D32) : const Color(0xFFB71C1C),
            ),
            SizedBox(width: 6.w),
            Text(
              isOpen ? "Buka" : "Tutup",
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
                color: isOpen
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFB71C1C),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: _red.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // title + open/close
          Row(
            children: [
              Expanded(
                child: Text(
                  bengkel.nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              statusChip(),
            ],
          ),
          SizedBox(height: 8.h),

          // alamat
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.place_rounded, size: 16.sp, color: Colors.grey[700]),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  bengkel.alamat,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),

          // meta row (rating + distance)
          SizedBox(height: 10.h),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Colors.orange, size: 18),
              SizedBox(width: 4.w),
              Text(
                bengkel.rating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              SizedBox(width: 10.w),
              Icon(Icons.near_me_rounded, size: 16.sp, color: Colors.grey[700]),
              SizedBox(width: 4.w),
              Text(
                distanceText,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),

          // route info hanya kalau ada
          if (hasRouteInfo) ...[
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: _yellow.withOpacity(0.22),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: _red.withOpacity(0.10)),
              ),
              child: Row(
                children: [
                  Icon(Icons.route_rounded, size: 18.sp, color: _red),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      "${routeDuration ?? "-"} • ${routeDistance ?? "-"}",
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if ((bengkel.deskripsi).trim().isNotEmpty) ...[
            SizedBox(height: 12.h),
            Text(
              bengkel.deskripsi,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[700],
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          SizedBox(height: 14.h),

          // actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  icon: const Icon(Icons.event_available_rounded, size: 18),
                  label: Text(
                    "Booking",
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEmergency,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _red.withOpacity(0.75), width: 1.4),
                    foregroundColor: _red,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  icon: const Icon(Icons.flash_on_rounded, size: 18),
                  label: Text(
                    "Darurat",
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 10.h),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: loadingRoute ? null : onDirections,
              style: ElevatedButton.styleFrom(
                backgroundColor: _yellow,
                foregroundColor: Colors.black87,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  side: BorderSide(color: _red.withOpacity(0.16)),
                ),
              ),
              icon: loadingRoute
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black87,
                      ),
                    )
                  : Icon(Icons.directions_rounded, size: 18, color: _red),
              label: Text(
                routeActive ? "Hapus Petunjuk Arah" : "Petunjuk Arah",
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
