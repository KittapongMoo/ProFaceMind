import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'setmap.dart'; // แผนที่
import 'camera.dart'; // กล้อง
import 'ownerinfo.dart'; // ข้อมูลผู้ใช้
import 'setphonenum.dart'; // ตั้งค่าเบอร์ฉุกเฉิน
import 'fillinfo.dart'; // กรอกข้อมูลรูปภาพ
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class SecondPage extends StatefulWidget {
  const SecondPage({Key? key}) : super(key: key);

  @override
  _SecondPageState createState() => _SecondPageState();
}

class _SecondPageState extends State<SecondPage> {
  late Future<Map<String, String>> _savedInformation;
  late Future<List<Map<String, dynamic>>> _usersFuture; // For DB records

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Helper to load data
  void _loadData() {
    _savedInformation = _loadSavedInformation();
    _usersFuture = _loadUsersWithImages();
  }

  Future<void> _deleteUser(BuildContext context, int userId) async {
    // Ask for confirmation
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirm Delete'),
            content: const Text('Are you sure you want to delete this user?'),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
              TextButton(
                child: const Text('Delete'),
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return; // User cancelled

    final db = await _getDatabase();

    // 1) Fetch the user's images so we can delete them from the file system
    final imageRows = await db
        .query('user_images', where: 'user_id = ?', whereArgs: [userId]);
    for (var row in imageRows) {
      final path = row['image_path'] as String;
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync(); // Delete the image file
      }
    }

    // 2) Delete from user_images
    await db.delete('user_images', where: 'user_id = ?', whereArgs: [userId]);

    // 3) Delete from users
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);

    // 4) Refresh the list
    setState(() {
      _usersFuture = _loadUsersWithImages();
    });
  }

  /// **📌 โหลดข้อมูลทั้งหมดจาก SharedPreferences**
  Future<Map<String, String>> _loadSavedInformation() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'nickname': prefs.getString('nickname') ?? 'ไม่พบข้อมูล',
      'firstname': prefs.getString('firstname') ?? 'ไม่พบข้อมูล',
      'lastname': prefs.getString('lastname') ?? 'ไม่พบข้อมูล',
      'birthdate': prefs.getString('birthdate') ?? 'ไม่พบข้อมูล',
      'height': prefs.getString('height') ?? 'ไม่พบข้อมูล',
      'weight': prefs.getString('weight') ?? 'ไม่พบข้อมูล',
      'condition': prefs.getString('condition') ?? 'ไม่พบข้อมูล',
      'emergency_name': prefs.getString('emergency_name') ?? 'ไม่พบข้อมูล',
      'emergency_relation':
          prefs.getString('emergency_relation') ?? 'ไม่พบข้อมูล',
      'emergency_phone': prefs.getString('emergency_phone') ?? 'ไม่พบข้อมูล',
      // 📍 โหลด Latitude และ Longitude
      'latitude':
          prefs.getDouble('selected_latitude')?.toString() ?? 'ไม่พบข้อมูล',
      'longitude':
          prefs.getDouble('selected_longitude')?.toString() ?? 'ไม่พบข้อมูล',
    };
  }

  /// Opens the existing database without re-creating it.
  Future<Database> _getDatabase() async {
    String dbPath = await getDatabasesPath();
    String path = p.join(dbPath, 'facemind.db');
    return openDatabase(path);
  }

  /// Loads all users plus their images in one query, grouped by user_id.
  Future<List<Map<String, dynamic>>> _loadUsersWithImages() async {
    final db = await _getDatabase();

    // Query with LEFT JOIN
    final List<Map<String, dynamic>> rawResults = await db.rawQuery('''
      SELECT 
        u.id, 
        u.nickname, 
        u.name, 
        u.relation, 
        u.primary_image,
        ui.image_path
      FROM users u
      LEFT JOIN user_images ui ON ui.user_id = u.id
    ''');

    // Group the data by user_id
    final Map<int, Map<String, dynamic>> groupedData = {};

    for (var row in rawResults) {
      final int userId = row['id'] as int;

      // If this user hasn't been added yet, create the base record
      if (!groupedData.containsKey(userId)) {
        groupedData[userId] = {
          'id': userId,
          'nickname': row['nickname'],
          'name': row['name'],
          'relation': row['relation'],
          'primary_image': row['primary_image'],
          'images': <String>[],
        };
      }

      // If there's an image_path, add it to the 'images' list
      if (row['image_path'] != null) {
        groupedData[userId]!['images'].add(row['image_path'] as String);
      }
    }

    // Return the grouped data as a list
    return groupedData.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ข้อมูลทั้งหมด'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SharedPreferences Data Section
            _buildSectionTitle('📌 ข้อมูลผู้ใช้ (SharedPreferences)'),
            FutureBuilder<Map<String, String>>(
              future: _savedInformation,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return const Center(
                      child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('ไม่มีข้อมูลที่บันทึกไว้'));
                }

                final data = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoTile('ชื่อเล่น', data['nickname']!),
                    _buildInfoTile('ชื่อจริง', data['firstname']!),
                    _buildInfoTile('นามสกุล', data['lastname']!),
                    _buildInfoTile('วันเกิด', data['birthdate']!),
                    _buildInfoTile('ส่วนสูง', data['height']!),
                    _buildInfoTile('น้ำหนัก', data['weight']!),
                    _buildInfoTile('โรคประจำตัว', data['condition']!),
                    _buildSectionTitle('📌 ข้อมูลเบอร์โทรฉุกเฉิน'),
                    _buildInfoTile('ชื่อ', data['emergency_name']!),
                    _buildInfoTile('ความสัมพันธ์', data['emergency_relation']!),
                    _buildInfoTile('เบอร์โทร', data['emergency_phone']!),
                    _buildSectionTitle('📌 ข้อมูลตำแหน่งที่เลือก'),
                    _buildInfoTile('ละติจูด', data['latitude']!),
                    _buildInfoTile('ลองจิจูด', data['longitude']!),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // New Section: Database Information
            // New Section: Database Information
            _buildSectionTitle('📌 ข้อมูลผู้ใช้ (จาก Database)'),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return const Center(
                      child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูลจากฐานข้อมูล'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text('ไม่พบข้อมูลผู้ใช้ในฐานข้อมูล'));
                }

                final users = snapshot.data!;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final int userId = user['id'] as int;
                    final String nickname = user['nickname'] ?? 'ไม่มีชื่อเล่น';
                    final String name = user['name'] ?? 'ไม่มีชื่อ';
                    final String relation =
                        user['relation'] ?? 'ไม่มีความสัมพันธ์';

                    // All images for this user
                    final List<String> imagePaths =
                        List<String>.from(user['images'] as List);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Basic user info
                            Text('ID: $userId',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text('ชื่อเล่น: $nickname'),
                            Text('ชื่อ: $name'),
                            Text('ความสัมพันธ์: $relation'),
                            const SizedBox(height: 10),

                            // Show a PageView of all images for this user
                            if (imagePaths.isNotEmpty) ...[
                              SizedBox(
                                height: 200,
                                child: PageView.builder(
                                  itemCount: imagePaths.length,
                                  itemBuilder: (ctx, i) {
                                    return GestureDetector(
                                      onTap: () {
                                        // Navigate to full image view when tapped.
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => FullImagePage(
                                                imagePath: imagePaths[i]),
                                          ),
                                        );
                                      },
                                      child: Image.file(
                                        File(imagePaths[i]),
                                        fit: BoxFit.cover,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ] else
                              const Text('ไม่พบรูปภาพของผู้ใช้คนนี้'),

                            const SizedBox(height: 10),
                            // DELETE BUTTON
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  tooltip: 'Delete User',
                                  onPressed: () => _deleteUser(context, userId),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 10),

            // Navigation Buttons Section
            _buildNavigationButton(
                'ตั้งค่าข้อมูลผู้ใช้', Colors.orange, const Ownerinfo()),
            const SizedBox(height: 10),
            _buildNavigationButton(
                'ตั้งค่าเบอร์โทรฉุกเฉิน', Colors.red, const SetPhoneNumber()),
            const SizedBox(height: 10),
            _buildNavigationButton(
                'ดูตำแหน่งแผนที่', Colors.green, const Setmap()),
            const SizedBox(height: 10),
            _buildNavigationButton(
                'เปิดกล้อง', Colors.blueAccent, const CameraPage()),
            const SizedBox(height: 25),
            // ปุ่มไปหน้า "กรอกข้อมูลรูปภาพ" ถ้าต้องการใช้งานเพิ่มได้
            // _buildNavigationButton('กรอกข้อมูลรูปภาพ', Colors.purple, const FillInfoPage()),
          ],
        ),
      ),
    );
  }

  /// **📌 Widget สำหรับหัวข้อแต่ละส่วน**
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  /// **📌 Widget แสดงข้อมูลแต่ละรายการ**
  Widget _buildInfoTile(String title, String value) {
    bool hasData = value != 'ไม่พบข้อมูล';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(
            hasData ? Icons.check_circle : Icons.warning_amber_rounded,
            color: hasData ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              '$title:',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: hasData ? Colors.black87 : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// **📌 Widget ปุ่มนำทางไปหน้าต่างๆ**
  Widget _buildNavigationButton(String title, Color color, Widget page) {
    return Center(
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => page),
          ).then((_) {
            // This code runs when the pushed route is popped,
            // regardless of whether the user tapped the in‑app back button or the device’s back button.
            setState(() {
              _loadData();
            });
          });
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          backgroundColor: color,
        ),
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
      ),
    );
  }
}

/// A new page to display the full image.
class FullImagePage extends StatelessWidget {
  final String imagePath;
  const FullImagePage({Key? key, required this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Full Image"),
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: InteractiveViewer(
          child: Image.file(File(imagePath)),
        ),
      ),
    );
  }
}
