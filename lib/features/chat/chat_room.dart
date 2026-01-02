// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ChatRoomPage extends StatefulWidget {
  final String chatId;
  final String title;

  /// Optional (buat kasus chat bengkel)
  final String? bengkelId;

  const ChatRoomPage({
    super.key,
    required this.chatId,
    required this.title,
    this.bengkelId,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _textC = TextEditingController();
  final _scrollC = ScrollController();
  bool _sending = false;
  bool _marking = false;

  String? _uid;

  DocumentReference<Map<String, dynamic>> get _chatRef =>
      FirebaseFirestore.instance.collection('chats').doc(widget.chatId);

  CollectionReference<Map<String, dynamic>> get _msgRef =>
      _chatRef.collection('messages');

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureChatExists();
      await _markRead();
    });
  }

  @override
  void dispose() {
    _textC.dispose();
    _scrollC.dispose();
    super.dispose();
  }

  Future<void> _ensureChatExists() async {
    final uid = _uid;
    if (uid == null) return;

    final snap = await _chatRef.get();
    if (snap.exists) return;

    final peerId = widget.bengkelId != null
        ? "bengkel:${widget.bengkelId}"
        : "peer:unknown";

    await _chatRef.set({
      "chatId": widget.chatId,
      "title": widget.title,
      "type": widget.bengkelId != null ? "bengkel" : "direct",
      "bengkelId": widget.bengkelId,
      "participants": [uid, peerId],
      "unread": {uid: 0, peerId: 0},
      "lastMessage": "",
      "lastMessageAt": FieldValue.serverTimestamp(),
      "createdAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _markRead() async {
    final uid = _uid;
    if (uid == null) return;
    if (_marking) return;

    _marking = true;
    try {
      // ✅ pakai dot-notation string biar aman di versi yang ketat Map<String,dynamic>
      await _chatRef.update({
        "unread.$uid": 0,
        "lastReadAt.$uid": FieldValue.serverTimestamp(),
      });
    } catch (_) {
      await _ensureChatExists();
      try {
        await _chatRef.update({
          "unread.$uid": 0,
          "lastReadAt.$uid": FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    } finally {
      _marking = false;
    }
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  Future<void> _send() async {
    final uid = _uid;
    if (uid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Kamu harus login dulu.")));
      return;
    }

    final text = _textC.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    _textC.clear();

    await _ensureChatExists();

    // cari peerId (buat increment unread peer)
    String? peerId;
    try {
      final chatSnap = await _chatRef.get();
      final data = chatSnap.data();
      final participants = (data?["participants"] as List?) ?? [];
      for (final p in participants) {
        final s = p.toString();
        if (s != uid) {
          peerId = s;
          break;
        }
      }
    } catch (_) {}

    final batch = FirebaseFirestore.instance.batch();
    final msgDoc = _msgRef.doc();

    batch.set(msgDoc, {
      "id": msgDoc.id,
      "text": text,
      "senderId": uid,
      "createdAt": FieldValue.serverTimestamp(),
    });

    // ✅ IMPORTANT: batch.update butuh Map<String, dynamic> (string key)
    final updates = <String, dynamic>{
      "lastMessage": text,
      "lastMessageAt": FieldValue.serverTimestamp(),
      "lastMessageSenderId": uid,
    };

    if (peerId != null && peerId.isNotEmpty) {
      // ✅ dot-notation untuk update nested map
      updates["unread.$peerId"] = FieldValue.increment(1);
    }

    batch.update(_chatRef, updates);

    try {
      await batch.commit();

      if (!mounted) return;
      await _markRead();

      if (_scrollC.hasClients) {
        _scrollC.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal kirim pesan: $e")));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const Divider(height: 1),
            Expanded(child: _buildMessagesList()),
            const Divider(height: 1),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: const Color(0xFFFFD740),
      padding: EdgeInsets.fromLTRB(8.w, 8.h, 16.w, 10.h),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.black),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _chatRef.snapshots(),
                  builder: (context, snap) {
                    final data = snap.data?.data();
                    final ts = data?["lastMessageAt"];
                    String sub = "—";
                    if (ts is Timestamp) {
                      sub = "Aktif ${_fmtTime(ts.toDate())}";
                    }
                    return Text(
                      sub,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.black.withOpacity(0.7),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    final uid = _uid;
    if (uid == null) {
      return const Center(child: Text("Silakan login untuk chat."));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _msgRef.orderBy("createdAt", descending: true).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(child: Text("Gagal memuat chat"));
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text(
              "Mulai chat yuk 👋",
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _markRead();
        });

        return ListView.builder(
          controller: _scrollC,
          reverse: true,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final text = (data["text"] ?? "").toString();
            final senderId = (data["senderId"] ?? "").toString();
            final isMe = senderId == uid;
            final ts = data["createdAt"];
            final time = (ts is Timestamp) ? _fmtTime(ts.toDate()) : "";

            return _MessageBubble(
              message: _Message(
                text: text,
                time: time,
                isMe: isMe,
                sender: isMe ? null : widget.title,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.add_circle_outline),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: TextField(
                controller: _textC,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (!_sending) _send();
                },
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Start typing...',
                  hintStyle: TextStyle(fontSize: 13.sp, color: Colors.grey),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.emoji_emotions_outlined),
          ),
          IconButton(
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final String text;
  final String time;
  final bool isMe;
  final String? sender;

  _Message({
    required this.text,
    required this.time,
    required this.isMe,
    this.sender,
  });
}

class _MessageBubble extends StatelessWidget {
  final _Message message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isMe) {
      return Padding(
        padding: EdgeInsets.only(left: 80.w, bottom: 8.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD740),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(message.text, style: TextStyle(fontSize: 13.sp)),
            ),
            SizedBox(height: 2.h),
            if (message.time.isNotEmpty)
              Text(
                message.time,
                style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
              ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: EdgeInsets.only(right: 80.w, bottom: 8.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14.r,
              backgroundColor: Colors.grey[300],
              child: Text(
                (message.sender != null && message.sender!.isNotEmpty)
                    ? message.sender![0].toUpperCase()
                    : 'B',
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.sender != null) ...[
                    Text(
                      message.sender!,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                  ],
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(fontSize: 13.sp),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  if (message.time.isNotEmpty)
                    Text(
                      message.time,
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.grey[600],
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
}
