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
import 'package:path/path.dart';

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
    _savedInformation = _loadSavedInformation();
    _usersFuture = _loadUsers();
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
      'emergency_relation': prefs.getString('emergency_relation') ?? 'ไม่พบข้อมูล',
      'emergency_phone': prefs.getString('emergency_phone') ?? 'ไม่พบข้อมูล',
      // 📍 โหลด Latitude และ Longitude
      'latitude': prefs.getDouble('selected_latitude')?.toString() ?? 'ไม่พบข้อมูล',
      'longitude': prefs.getDouble('selected_longitude')?.toString() ?? 'ไม่พบข้อมูล',
    };
  }

  /// Opens the existing database without re-creating it.
  Future<Database> _getDatabase() async {
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, 'facemind.db');
    return openDatabase(path);
  }

  /// Loads all records from the "users" table in the existing database.
  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final db = await _getDatabase();
    List<Map<String, dynamic>> users = await db.query('users');
    return users;
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
                  return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
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
            _buildSectionTitle('📌 ข้อมูลผู้ใช้ (จาก Database)'),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูลจากฐานข้อมูล'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('ไม่พบข้อมูลผู้ใช้ในฐานข้อมูล'));
                }

                final users = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ListTile(
                        leading: (user['primary_image'] != null &&
                                user['primary_image'].toString().isNotEmpty)
                            ? Image.file(
                                File(user['primary_image']),
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.person, size: 50),
                        title: Text(user['nickname'] ?? 'ไม่มีชื่อเล่น'),
                        subtitle: Text(
                          'ชื่อ: ${user['name'] ?? 'ไม่มีชื่อ'}\nความสัมพันธ์: ${user['relation'] ?? 'ไม่มีความสัมพันธ์'}',
                        ),
                        onTap: () {
                          // Optionally, add navigation to a detailed view.
                        },
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 40),

            // Navigation Buttons Section
            _buildNavigationButton('ตั้งค่าข้อมูลผู้ใช้', Colors.orange, const Ownerinfo()),
            _buildNavigationButton('ตั้งค่าเบอร์โทรฉุกเฉิน', Colors.red, const SetPhoneNumber()),
            _buildNavigationButton('ดูตำแหน่งแผนที่', Colors.green, const Setmap()),
            _buildNavigationButton('เปิดกล้อง', Colors.blueAccent, const CameraPage()),
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
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
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
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (context) => page),
        );
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
