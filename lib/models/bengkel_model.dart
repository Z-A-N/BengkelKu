// ignore_for_file: non_constant_identifier_names

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

  Bengkel({
    required this.id,
    required this.nama,
    required this.alamat,
    required this.deskripsi,
    required this.rating,
    required this.buka,
    required this.foto,
    required this.telepon,
    required this.lokasi,
    required this.jamOperasional,BengkelDetailPage
  });

  factory Bengkel.fromDoc(DocumentSnapshot doc) {
  final data = (doc.data() as Map<String, dynamic>?) ?? {};

  final ratingRaw = data['rating'];
  final rating = ratingRaw is num ? ratingRaw.toDouble() : 0.0;

  return Bengkel(
    id: doc.id,
    nama: (data['nama'] ?? '-') as String,
    alamat: (data['alamat'] ?? '-') as String,
    deskripsi: (data['deskripsi'] ?? '') as String,
    rating: rating,
    buka: (data['buka'] ?? false) as bool,
    foto: (data['foto'] ?? '') as String,
    telepon: (data['telepon'] ?? '-') as String,
    lokasi: data['lokasi'] is GeoPoint ? data['lokasi'] as GeoPoint : const GeoPoint(0, 0),
    jamOperasional: (data['jam_operasional'] as Map<String, dynamic>?) ?? {},
  );
}

}
