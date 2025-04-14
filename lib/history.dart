// Optimized HistoryPage with lazy image loading and memory-safe database access.

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:math' as math;
import 'package:facemind/database_helper.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late DateTime _selectedDate;
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _historyFuture = _loadHistory(_selectedDate);
  }

  Future<List<Map<String, dynamic>>> _loadHistory(DateTime date) async {
    final db = await DatabaseHelper().database;
    final formattedDate = "${date.year.toString().padLeft(4, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
    return await db.rawQuery('''
      SELECT h.id, h.user_id, h.matched_at, u.nickname
      FROM history h
      LEFT JOIN users u ON u.id = h.user_id
      WHERE date(h.matched_at) = ?
      ORDER BY h.matched_at DESC
      LIMIT 30
    ''', [formattedDate]);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _historyFuture = _loadHistory(_selectedDate);
      });
    }
  }

  Future<void> _deleteHistoryRecord(int id) async {
    final db = await DatabaseHelper().database;
    await db.delete('history', where: 'id = ?', whereArgs: [id]);
    setState(() {
      _historyFuture = _loadHistory(_selectedDate);
    });
  }

  Future<Uint8List?> _loadFaceImage(int recordId) async {
    final db = await DatabaseHelper().database;
    final result = await db.query(
      'history',
      columns: ['face_image'],
      where: 'id = ?',
      whereArgs: [recordId],
      limit: 1,
    );
    if (result.isNotEmpty) {
      final blob = result.first['face_image'];
      if (blob != null) {
        return Uint8List.fromList((blob as List).cast<int>());
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final displayDate = "${_selectedDate.day.toString().padLeft(2, '0')}/"
        "${_selectedDate.month.toString().padLeft(2, '0')}/"
        "${_selectedDate.year}";
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'ประวัติการสแกน',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        displayDate,
                        style: const TextStyle(
                            fontSize: 16, color: Colors.black54),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.black54),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _historyFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(
                          child: Text('เกิดข้อผิดพลาดในการโหลดประวัติ'));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                          child: Text('ไม่มีประวัติสำหรับวันที่นี้'));
                    }
                    final historyRecords = snapshot.data!;
                    return ListView.builder(
                      itemCount: historyRecords.length,
                      itemBuilder: (context, index) {
                        final record = historyRecords[index];
                        final recordId = record['id'] as int;
                        final nickname = record['nickname'] ?? 'ไม่ทราบชื่อ';
                        final matchedAt = record['matched_at'] as String;
                        DateTime matchedDateTime = DateTime.parse(matchedAt);
                        final timeString =
                            "${matchedDateTime.hour.toString().padLeft(2, '0')}:"
                            "${matchedDateTime.minute.toString().padLeft(2, '0')}";

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: FutureBuilder<Uint8List?>(
                              future: _loadFaceImage(recordId),
                              builder: (context, snapshot) {
                                final faceImageBytes = snapshot.data;
                                return GestureDetector(
                                  onTap: () {
                                    if (faceImageBytes != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => FullImageScreen(
                                            imageBytes: faceImageBytes,
                                            title: 'Scanned Image',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: CircleAvatar(
                                    radius: 35,
                                    backgroundColor: Colors.grey.shade300,
                                    backgroundImage: faceImageBytes != null
                                        ? MemoryImage(faceImageBytes)
                                        : const AssetImage(
                                                'assets/images/test_user.jpg')
                                            as ImageProvider,
                                  ),
                                );
                              },
                            ),
                            title: Text('ชื่อ: $nickname',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                )),
                            subtitle: Text('เวลา: $timeString',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                )),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('การลบข้อมูล'),
                                      content: const Text(
                                          'คุณแน่ใจหรือไม่ที่จะทำการยินยันในการลบประวัติการสแกนใบหน้าของบุคคลท่านนี้?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('ยกเลิก'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            await _deleteHistoryRecord(
                                                recordId);
                                          },
                                          child: const Text('ยืนยัน'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
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

class FullImageScreen extends StatelessWidget {
  final Uint8List imageBytes;
  final String? title;

  const FullImageScreen({Key? key, required this.imageBytes, this.title})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'Full Image')),
      body: Center(
        child: InteractiveViewer(
          child: Transform.rotate(
            angle: math.pi / 2,
            child: Image.memory(imageBytes),
          ),
        ),
      ),
    );
  }
}
