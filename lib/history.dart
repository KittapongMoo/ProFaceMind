import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:math' as math;
import 'package:facemind/database_helper.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';  // for Thai month names

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
    // Updated query to also fetch 'name' and 'relation'
    return await db.rawQuery('''
      SELECT h.id, h.user_id, h.matched_at, u.nickname, u.name, u.relation
      FROM history h
      LEFT JOIN users u ON u.id = h.user_id
      WHERE date(h.matched_at) = ?
      ORDER BY h.matched_at DESC
      LIMIT 500
    ''', [formattedDate]);
  }

  Future<void> _selectDate(BuildContext context) async {
    final pickedDate = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        DateTime tempDate = _selectedDate;
        return StatefulBuilder(builder: (context, setModalState) {
          return SizedBox(
            height: 300,
            child: Column(
              children: [
                // ── Cancel / Confirm ───────────────────
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Text('ยกเลิก'),
                        onPressed: () => Navigator.pop(context),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Text('เลือก'),
                        onPressed: () => Navigator.pop(context, tempDate),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // ── Your custom ThaiDatePicker ───────────────────
                Expanded(
                  child: ThaiDatePicker(
                    initialDate: _selectedDate,
                    minimumDate: DateTime(2020, 1, 1),
                    maximumDate: DateTime.now(),
                    onDateChanged: (year, month, day) {
                      setModalState(() {
                        tempDate = DateTime(year, month, day);
                      });
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate  = pickedDate;
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
    final day       = _selectedDate.day.toString().padLeft(2, '0');
    final monthName = DateFormat.MMMM('th_TH').format(_selectedDate);
    final beYear   = _selectedDate.year + 543;
    final displayDate = "$day $monthName $beYear";
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
                        final name = record['name'] ?? 'ไม่ทราบชื่อ';
                        final relation = record['relation'] ?? 'ไม่ทราบชื่อ';
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
                            // Updated title to include nickname, name, and relation.
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ชื่อเล่น: $nickname',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'ชื่อ: $name',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'ความสัมพันธ์: $relation',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text('เวลา: $timeString น.',
                                style: const TextStyle(
                                  fontSize: 16,
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

  const FullImageScreen({Key? key, required this.imageBytes, this.title})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'Full Image')),
      body: Center(
        child: InteractiveViewer(
          child: Image.memory(imageBytes),
        ),
      ),
    );
  }
}

class ThaiDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime minimumDate;
  final DateTime maximumDate;

  final void Function(int year, int month, int day)? onDateChanged;
  const ThaiDatePicker({
    Key? key,
    required this.initialDate,
    required this.minimumDate,
    required this.maximumDate,
    this.onDateChanged,
  }) : super(key: key);

  @override
  _ThaiDatePickerState createState() => _ThaiDatePickerState();
}

class _ThaiDatePickerState extends State<ThaiDatePicker> {
  late int selectedDay, selectedMonth, selectedYear;
  late List<int> years;

  @override
  void initState() {
    super.initState();
    selectedDay   = widget.initialDate.day;
    selectedMonth = widget.initialDate.month;
    selectedYear  = widget.initialDate.year;
    years = List<int>.generate(
      widget.maximumDate.year - widget.minimumDate.year + 1,
          (i) => widget.minimumDate.year + i,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // Day
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 32,
                  scrollController: FixedExtentScrollController(initialItem: selectedDay - 1),
                  onSelectedItemChanged: (i) {
                    setState(() => selectedDay = i + 1);
                    widget.onDateChanged?.call(selectedYear, selectedMonth, selectedDay);
                  },
                  children: List.generate(31, (i) => Center(child: Text('${i + 1}'))),
                ),
              ),
              // Month (Thai)
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 32,
                  scrollController: FixedExtentScrollController(initialItem: selectedMonth - 1),
                  onSelectedItemChanged: (i) {
                    setState(() => selectedMonth = i + 1);
                    widget.onDateChanged?.call(selectedYear, selectedMonth, selectedDay);
                  },
                  children: List.generate(12, (i) {
                    final m = DateFormat.MMMM('th_TH').format(DateTime(2000, i + 1));
                    return Center(child: Text(m));
                  }),
                ),
              ),
              // Year (B.E.)
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 32,
                  scrollController: FixedExtentScrollController(
                      initialItem: selectedYear - widget.minimumDate.year),
                  onSelectedItemChanged: (i) {
                    setState(() => selectedYear = years[i]);
                    widget.onDateChanged?.call(selectedYear, selectedMonth, selectedDay);
                  },
                  children: years.map((y) => Center(child: Text('${y + 543}'))).toList(),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

