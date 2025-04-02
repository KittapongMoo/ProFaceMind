import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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

  // Use the same database (facemind.db) for both users and history.
  Future<Database> _getHistoryDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'facemind.db');
    // Open the database.
    Database db = await openDatabase(
      path,
      version: 2,
      onOpen: (Database db) async {
        print("Database opened: $path");
      },
    );
    // Ensure the history table exists.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        matched_at TEXT
      )
    ''');
    return db;
  }

  // Load history records for the given date.
  // This query joins the history table with the users table.
  Future<List<Map<String, dynamic>>> _loadHistory(DateTime date) async {
    final db = await _getHistoryDatabase();
    // Format date as yyyy-MM-dd to use with SQLite's date() function.
    final formattedDate = "${date.year.toString().padLeft(4, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
    return await db.rawQuery('''
      SELECT h.*, u.nickname, u.primary_image
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
      final db = await _getHistoryDatabase();
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
    final db = await _getHistoryDatabase();
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        displayDate,
                        style: const TextStyle(fontSize: 16, color: Colors.black54),
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
                      return const Center(child: Text('ไม่มีประวัติสำหรับวันที่นี้'));
                    }
                    final historyRecords = snapshot.data!;
                    return ListView.builder(
                      itemCount: historyRecords.length,
                      itemBuilder: (context, index) {
                        final record = historyRecords[index];
                        final recordId = record['id'] as int;
                        final nickname = record['nickname'] ?? 'ไม่ทราบชื่อ';
                        final primaryImage = record['primary_image'] as String?;
                        final matchedAt = record['matched_at'] as String;
                        // Parse matchedAt to a DateTime.
                        DateTime matchedDateTime = DateTime.parse(matchedAt);
                        final timeString = "${matchedDateTime.hour.toString().padLeft(2, '0')}:"
                            "${matchedDateTime.minute.toString().padLeft(2, '0')}";
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 35,
                              backgroundImage: (primaryImage != null &&
                                  primaryImage.isNotEmpty &&
                                  File(primaryImage).existsSync())
                                  ? FileImage(File(primaryImage))
                                  : const AssetImage('assets/images/test_user.jpg')
                              as ImageProvider,
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
                                      title: const Text('Confirm Deletion'),
                                      content: const Text(
                                          'Are you sure you want to delete this history record?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            await _deleteHistoryRecord(recordId);
                                          },
                                          child: const Text('Delete'),
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
