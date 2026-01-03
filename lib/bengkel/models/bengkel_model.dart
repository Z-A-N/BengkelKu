import 'package:cloud_firestore/cloud_firestore.dart';

class Bengkel {
  final String id;
  final String nama;
  final String alamat;
  final String deskripsi;
  final double rating;
  final bool buka;
  final String foto;
  final String telepon;
  final GeoPoint lokasi;
  final Map<String, dynamic> jamOperasional;

  const Bengkel({
    required this.id,
    required this.nama,
    required this.alamat,
    required this.deskripsi,
    required this.rating,
    required this.buka,
    required this.foto,
    required this.telepon,
    required this.lokasi,
    required this.jamOperasional,
  });

  factory Bengkel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final ratingRaw = data['rating'];
    final rating = ratingRaw is num ? ratingRaw.toDouble() : 0.0;

    final lokasiRaw = data['lokasi'];
    final lokasi = lokasiRaw is GeoPoint ? lokasiRaw : const GeoPoint(0, 0);

    return Bengkel(
      id: doc.id,
      nama: (data['nama'] ?? '-') as String,
      alamat: (data['alamat'] ?? '-') as String,
      deskripsi: (data['deskripsi'] ?? '') as String,
      rating: rating,
      buka: (data['buka'] ?? false) as bool,
      foto: (data['foto'] ?? '') as String,
      telepon: (data['telepon'] ?? '-') as String,
      lokasi: lokasi,
      jamOperasional: (data['jam_operasional'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// Buat kebutuhan map / marker
  double get lat => lokasi.latitude;
  double get lng => lokasi.longitude;
}
