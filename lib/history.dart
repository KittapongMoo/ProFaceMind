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
    _checkHistoryDatabase(); // Debug function call.
  }

  // Load history records for the given date.
  // This query joins the history table with the users table.
  Future<List<Map<String, dynamic>>> _loadHistory(DateTime date) async {
    final db = await DatabaseHelper().database;
    // Format date as yyyy-MM-dd to use with SQLite's date() function.
    final formattedDate = "${date.year.toString().padLeft(4, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
    return await db.rawQuery('''
      SELECT h.*, u.nickname
      FROM history h
      LEFT JOIN users u ON u.id = h.user_id
      WHERE date(h.matched_at) = ?
      ORDER BY h.matched_at DESC
    ''', [formattedDate]);
  }

  // Open the date picker and update the history list.
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020), // Adjust as needed.
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _historyFuture = _loadHistory(_selectedDate);
      });
    }
  }

  // Debug function to check the history database.
  Future<void> _checkHistoryDatabase() async {
    try {
      final db = await DatabaseHelper().database;
      final tableInfo = await db.rawQuery("PRAGMA table_info(history)");
      print("Table info for 'history': $tableInfo");

      final contents = await db.rawQuery("SELECT * FROM history");
      print("⏳⏳⏳Contents of 'history': $contents");
    } catch (e) {
      print("❌❌❌Error checking history database: $e");
    }
  }

  // Delete a history record by its id.
  Future<void> _deleteHistoryRecord(int id) async {
    final db = await DatabaseHelper().database;
    await db.delete('history', where: 'id = ?', whereArgs: [id]);
    // Refresh the list.
    setState(() {
      _historyFuture = _loadHistory(_selectedDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Format the date for display (dd/MM/yyyy).
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
              // Date selector container.
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
              // History records list.
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

                        // Retrieve the face_image blob as dynamic.
                        final dynamic blobData = record['face_image'];
                        Uint8List? faceImageBytes;
                        if (blobData != null) {
                          try {
                            // Convert blobData to Uint8List.
                            faceImageBytes = Uint8List.fromList(blobData.cast<int>());
                            print("Retrieved face image blob of length: ${faceImageBytes.length}");
                          } catch (e) {
                            print("Error converting blob to Uint8List: $e");
                          }
                        }

                        // Parse matchedAt to a DateTime.
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
                            leading: GestureDetector(
                              onTap: () {
                                if (faceImageBytes != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FullImageScreen(
                                        imageBytes: faceImageBytes!, // use ! to assert non-null
                                        title: 'Scanned Image',
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                width: 60,
                                height: 70,
                                child: faceImageBytes != null
                                    ? Transform.rotate(
                                  angle: math.pi/2, // 180° rotation; adjust if needed
                                  child: ClipOval(
                                    child: Image.memory(
                                      faceImageBytes,
                                      fit: BoxFit.cover,
                                      width: 70,
                                      height: 70,
                                    ),
                                  ),
                                )
                                    : CircleAvatar(
                                  radius: 35,
                                  backgroundImage:
                                  const AssetImage('assets/images/test_user.jpg'),
                                ),
                              ),
                            ),
                            title: Text(
                              'ชื่อ: $nickname',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'เวลา: $timeString',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                // Show a confirmation dialog.
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('การลบข้อมูล'),
                                      content: const Text('คุณแน่ใจหรือไม่ที่จะทำการยินยันในการลบประวัติการสแกนใบหน้าของบุคคลท่านนี้?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('ยกเลิก'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            await _deleteHistoryRecord(recordId);
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

  const FullImageScreen({Key? key, required this.imageBytes, this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'Full Image'),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Transform.rotate(
            angle: math.pi / 2, // rotates the image -90° (counterclockwise)
            child: Image.memory(imageBytes),
          ),
        ),
      ),
    );
  }
}
