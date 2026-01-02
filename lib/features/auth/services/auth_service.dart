import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum AuthStartDestination { onboarding, vehicleForm, home }

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // google_sign_in v7: pakai singleton instance
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FacebookAuth _facebookAuth = FacebookAuth.instance;

  bool _googleInitialized = false;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await _googleSignIn.initialize();
    _googleInitialized = true;
  }

  // Helper
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;

  bool get currentUserHasPasswordProvider {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  Future<void> _ensureUserDocument(User user, {String? nameOverride}) async {
    final docRef = _db.collection("users").doc(user.uid);
    final snap = await docRef.get();

    final data = <String, dynamic>{
      "uid": user.uid,
      "email": user.email,
      "name": nameOverride ?? user.displayName ?? "",
      "updatedAt": FieldValue.serverTimestamp(),
    };

    if (!snap.exists) {
      data["createdAt"] = FieldValue.serverTimestamp();
    }

    await docRef.set(data, SetOptions(merge: true));
  }

  // ===========================
  // LOGIN EMAIL & PASSWORD
  // ===========================
  Future<User?> login({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  // ===========================
  // REGISTER
  // ===========================
  Future<User?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = cred.user;
    if (user != null) {
      await user.updateDisplayName(name);
      await _ensureUserDocument(user, nameOverride: name);
    }

    return user;
  }

  // ===========================
  // CEK EMAIL TERDAFTAR (Firestore)
  // ===========================
  Future<bool> emailExists(String email) async {
    final snap = await _db
        .collection("users")
        .where("email", isEqualTo: email)
        .limit(1)
        .get();

    return snap.docs.isNotEmpty;
  }

  // ===========================
  // RESET PASSWORD
  // ===========================
  Future<void> sendResetPasswordEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ===========================
  // UBAH / BUAT KATA SANDI
  // ===========================
  Future<bool> changeOrCreatePassword({
    String? oldPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(
        code: 'no-user',
        message: 'User tidak ditemukan. Silakan login ulang.',
      );
    }

    final email = user.email!;
    final hasPassword = user.providerData.any(
      (p) => p.providerId == 'password',
    );

    if (hasPassword) {
      if (oldPassword == null || oldPassword.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-old-password',
          message: 'Kata sandi lama wajib diisi.',
        );
      }

      final cred = EmailAuthProvider.credential(
        email: email,
        password: oldPassword,
      );

      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      return true; // true = update password
    } else {
      final cred = EmailAuthProvider.credential(
        email: email,
        password: newPassword,
      );

      await user.linkWithCredential(cred);
      return false; // false = create/link password
    }
  }

  // ===========================
  // CEK DATA KENDARAAN
  // ===========================
  Future<bool> hasVehicleData(String uid) async {
    final doc = await _db
        .collection("users")
        .doc(uid)
        .collection("vehicle")
        .doc("main")
        .get();

    return doc.exists;
  }

  // ===========================
  // SIMPAN DATA KENDARAAN
  // ===========================
  Future<void> saveVehicleData({
    required String uid,
    required String jenis,
    required String nomorPolisi,
    String? merek,
    String? model,
    String? tahun,
    String? km,
  }) async {
    await _db
        .collection("users")
        .doc(uid)
        .collection("vehicle")
        .doc("main")
        .set({
          "jenis": jenis,
          "nomorPolisi": nomorPolisi,
          "merek": merek,
          "model": model,
          "tahun": tahun,
          "km": km,
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  // ===========================
  // LOGIN GOOGLE
  // ===========================
  Future<User?> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      final userCred = await _auth.signInWithPopup(provider);
      final user = userCred.user;
      if (user != null) {
        await _ensureUserDocument(user);
      }
      return user;
    }

    await _ensureGoogleInitialized();

    if (!_googleSignIn.supportsAuthenticate()) {
      throw UnsupportedError('Google Sign-In tidak didukung di platform ini.');
    }

    try {
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      // aman untuk future/non-future
      final googleAuth = await googleUser.authentication;

      final String? idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'google-id-token-null',
          message:
              'Gagal mendapatkan idToken dari Google. Cek konfigurasi Google Sign-In (SHA-1/SHA-256 Android dan provider Google di Firebase).',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);

      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user;

      if (user != null) {
        await _ensureUserDocument(user);
      }
      return user;
    } on GoogleSignInException catch (e) {
      if (e.code == 'canceled') return null;
      rethrow;
    }
  }

  // ===========================
  // LOGIN FACEBOOK
  // ===========================
  Future<User?> signInWithFacebook() async {
    final result = await _facebookAuth.login();

    if (result.status == LoginStatus.cancelled) return null;

    if (result.status != LoginStatus.success) {
      throw FirebaseAuthException(
        code: 'facebook-login-failed',
        message: 'Login Facebook gagal.',
      );
    }

    final accessToken = result.accessToken;
    if (accessToken == null) {
      throw FirebaseAuthException(
        code: 'facebook-no-token',
        message: 'Gagal mendapatkan token Facebook.',
      );
    }

    final userCred = await _auth.signInWithCredential(
      FacebookAuthProvider.credential(accessToken.tokenString),
    );

    final user = userCred.user;
    if (user != null) {
      await _ensureUserDocument(user);
    }

    return user;
  }

  // ===========================
  // LOGOUT
  // ===========================
  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    try {
      await _facebookAuth.logOut();
    } catch (_) {}

    await _auth.signOut();
  }

  // ===========================
  // LOGIKA AWAL SETELAH APP DIBUKA
  // ===========================
  Future<AuthStartDestination> resolveStartDestination() async {
    final user = _auth.currentUser;

    if (user == null) return AuthStartDestination.onboarding;

    try {
      final hasVehicle = await hasVehicleData(user.uid);
      return hasVehicle
          ? AuthStartDestination.home
          : AuthStartDestination.vehicleForm;
    } catch (_) {
      return AuthStartDestination.home;
    }
  }
}
