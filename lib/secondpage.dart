import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'setmap.dart'; // Import แผนที่
import 'camera.dart'; // Import กล้อง
import 'ownerinfo.dart'; // Import ข้อมูลผู้ใช้
import 'setphonenum.dart'; // Import ตั้งค่าเบอร์ฉุกเฉิน

class SecondPage extends StatefulWidget {
  const SecondPage({Key? key}) : super(key: key);

  @override
  _SecondPageState createState() => _SecondPageState();
}

class _SecondPageState extends State<SecondPage> {
  late Future<Map<String, String>> _savedInformation;

  @override
  void initState() {
    super.initState();
    _loadSavedInformation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSavedInformation();
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
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ข้อมูลทั้งหมด'),
        backgroundColor: Colors.blue,
      ),
      body: FutureBuilder<Map<String, String>>(
        future: _loadSavedInformation(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('ไม่มีข้อมูลที่บันทึกไว้'));
          }

          final data = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📌 ข้อมูลผู้ใช้:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _buildInfoTile('ชื่อเล่น', data['nickname']!),
                _buildInfoTile('ชื่อจริง', data['firstname']!),
                _buildInfoTile('นามสกุล', data['lastname']!),
                _buildInfoTile('วันเกิด', data['birthdate']!),
                _buildInfoTile('ส่วนสูง', data['height']!),
                _buildInfoTile('น้ำหนัก', data['weight']!),
                _buildInfoTile('โรคประจำตัว', data['condition']!),

                const SizedBox(height: 30),

                const Text(
                  '📌 ข้อมูลเบอร์โทรฉุกเฉิน:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _buildInfoTile('ชื่อ', data['emergency_name']!),
                _buildInfoTile('ความสัมพันธ์', data['emergency_relation']!),
                _buildInfoTile('เบอร์โทร', data['emergency_phone']!),

                const SizedBox(height: 40),

                // 🔹 ปุ่มไปหน้า "ตั้งค่าผู้ใช้"
                _buildNavigationButton(
                  'ตั้งค่าข้อมูลผู้ใช้',
                  Colors.orange,
                  const Ownerinfo(),
                ),

                const SizedBox(height: 20),

                // 🔹 ปุ่มไปหน้า "ตั้งค่าเบอร์โทรฉุกเฉิน"
                _buildNavigationButton(
                  'ตั้งค่าเบอร์โทรฉุกเฉิน',
                  Colors.red,
                  const SetPhoneNumber(),
                ),

                const SizedBox(height: 20),

                // 🔹 ปุ่มไปหน้า "แผนที่"
                _buildNavigationButton(
                  'ดูตำแหน่งแผนที่',
                  Colors.green,
                  const Setmap(),
                ),

                const SizedBox(height: 20),

                // 🔹 ปุ่มไปหน้า "กล้อง"
                _buildNavigationButton(
                  'เปิดกล้อง',
                  Colors.blueAccent,
                  const CameraPage(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// **📌 Widget แสดงข้อมูลแต่ละรายการ**
  Widget _buildInfoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$title:',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
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
          Navigator.push(context, MaterialPageRoute(builder: (context) => page));
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
