// ignore_for_file: unnecessary_underscores

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'chat_room.dart';

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final _searchC = TextEditingController();
  String _q = "";

  bool _bootstrapped = false;
  bool _bootstrapping = false;

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  DateTime _toDate(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _norm(String s) => s.toLowerCase().trim();

  bool _isBatal(String s) {
    s = _norm(s);
    return s.contains("batal") ||
        s.contains("cancelled") ||
        s.contains("canceled");
  }

  /// ✅ bikin chatId unik per (user x bengkel)
  String _chatIdForBengkel({required String uid, required String bengkelId}) {
    return "bengkel_${bengkelId}_$uid";
  }

  /// ✅ AUTO: pastikan room chat ada berdasarkan booking user
  Future<void> _bootstrapChatRoomsFromBookings(String uid) async {
    if (_bootstrapping) return;
    _bootstrapping = true;

    try {
      // Ambil booking milik user (tanpa orderBy biar minim index)
      final qs = await FirebaseFirestore.instance
          .collection("bookings")
          .where("userId", isEqualTo: uid)
          .limit(50)
          .get();

      for (final b in qs.docs) {
        final data = b.data();

        final status = (data["status"] ?? "").toString();
        if (_isBatal(status)) continue; // skip booking batal

        final bengkelId = (data["bengkelId"] ?? "").toString().trim();
        if (bengkelId.isEmpty) continue;

        final bengkelNama = (data["bengkelNama"] ?? "Bengkel").toString();

        final chatId = _chatIdForBengkel(uid: uid, bengkelId: bengkelId);
        final chatRef = FirebaseFirestore.instance
            .collection("chats")
            .doc(chatId);

        final chatSnap = await chatRef.get();
        if (chatSnap.exists) continue; // ✅ sudah ada room-nya

        final peerId = "bengkel:$bengkelId";

        await chatRef.set({
          "chatId": chatId,
          "type": "bengkel",
          "title": bengkelNama,
          "bengkelId": bengkelId,
          // optional kalau kamu mau simpan referensi booking terakhir
          "lastBookingId": b.id,

          "participants": [uid, peerId],
          "unread": {uid: 0, peerId: 0},

          "lastMessage": "",
          // biar chat baru langsung muncul di atas, boleh pakai serverTimestamp
          "lastMessageAt": FieldValue.serverTimestamp(),
          "createdAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      // gak usah ganggu UI, cukup debug
      // ignore: avoid_print
      print("bootstrap chat error: $e");
    } finally {
      _bootstrapping = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // ✅ jalankan sekali pas user sudah login
    if (user != null && !_bootstrapped) {
      _bootstrapped = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _bootstrapChatRoomsFromBookings(user.uid);
      });
    }

    return Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16.h),

              Center(
                child: Text(
                  'Chat Bengkel',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              SizedBox(height: 16.h),

              // Search bar
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey[600]),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: TextField(
                        controller: _searchC,
                        onChanged: (v) =>
                            setState(() => _q = v.trim().toLowerCase()),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Cari',
                          hintStyle: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              Expanded(
                child: (user == null)
                    ? Center(
                        child: Text(
                          "Silakan login untuk melihat chat.",
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.grey[700],
                          ),
                        ),
                      )
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        // ✅ TANPA orderBy biar gak butuh index
                        stream: FirebaseFirestore.instance
                            .collection('chats')
                            .where('participants', arrayContains: user.uid)
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
                                "Gagal memuat chat.\n${snap.error}",
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
                                "Belum ada chat.",
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Colors.grey[700],
                                ),
                              ),
                            );
                          }

                          // ✅ sort manual by lastMessageAt desc
                          docs.sort((a, b) {
                            final da = _toDate(a.data()['lastMessageAt']);
                            final db = _toDate(b.data()['lastMessageAt']);
                            return db.compareTo(da);
                          });

                          // filter search
                          final filtered = docs.where((d) {
                            final title = (d.data()['title'] ?? '')
                                .toString()
                                .toLowerCase();
                            if (_q.isEmpty) return true;
                            return title.contains(_q);
                          }).toList();

                          return ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => SizedBox(height: 12.h),
                            itemBuilder: (context, index) {
                              final d = filtered[index];
                              final data = d.data();

                              final title = (data['title'] ?? 'Chat')
                                  .toString();
                              final last = (data['lastMessage'] ?? '')
                                  .toString();

                              final dt = _toDate(data['lastMessageAt']);
                              final time = dt.millisecondsSinceEpoch == 0
                                  ? ''
                                  : _fmtTime(dt);

                              final unreadMap = data['unread'];
                              int unread = 0;
                              if (unreadMap is Map) {
                                final v = unreadMap[user.uid];
                                if (v is int) unread = v;
                                if (v is num) unread = v.toInt();
                              }

                              final isBengkel =
                                  (data['type']?.toString() == 'bengkel');

                              return _ChatTile(
                                title: title,
                                lastMessage: last,
                                time: time,
                                unreadCount: unread,
                                isBengkel: isBengkel,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatRoomPage(
                                        chatId: d.id,
                                        title: title,
                                        bengkelId: data['bengkelId']
                                            ?.toString(),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final String title;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isBengkel;
  final VoidCallback onTap;

  const _ChatTile({
    required this.title,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isBengkel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 22.r,
            backgroundColor: isBengkel
                ? const Color(0xFFFFD740)
                : Colors.grey[300],
            child: Text(
              title.isNotEmpty ? title[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18.sp,
                color: Colors.black87,
              ),
            ),
          ),
          SizedBox(width: 10.w),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  lastMessage.isEmpty ? "—" : lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
                ),
              ],
            ),
          ),

          SizedBox(width: 8.w),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time.isEmpty ? " " : time,
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
              ),
              SizedBox(height: 6.h),
              if (unreadCount > 0)
                Container(
                  width: 18.w,
                  height: 18.w,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFEB5757),
                  ),
                  child: Center(
                    child: Text(
                      unreadCount.toString(),
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
