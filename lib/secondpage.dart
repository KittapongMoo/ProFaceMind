import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import 'setmap.dart'; // Import ThirdPage
import 'camera.dart';
import 'ownerinfo.dart';

class SecondPage extends StatelessWidget {
  const SecondPage({super.key});

  Future<Map<String, String>> getSavedInformation() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'nickname': prefs.getString('nickname') ?? 'ไม่พบข้อมูล',
      'firstname': prefs.getString('firstname') ?? 'ไม่พบข้อมูล',
      'lastname': prefs.getString('lastname') ?? 'ไม่พบข้อมูล',
      'birthdate': prefs.getString('birthdate') ?? 'ไม่พบข้อมูล',
      'height': prefs.getString('height') ?? 'ไม่พบข้อมูล',
      'weight': prefs.getString('weight') ?? 'ไม่พบข้อมูล',
      'condition': prefs.getString('condition') ?? 'ไม่พบข้อมูล',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Second Page'),
        backgroundColor: Colors.blue,
      ),
      body: FutureBuilder<Map<String, String>>(
        future: getSavedInformation(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Failed to load data.'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No data found.'));
          }

          final data = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ข้อมูลที่บันทึกไว้:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text('ชื่อเล่น: ${data['nickname']}'),
                Text('ชื่อจริง: ${data['firstname']}'),
                Text('นามสกุล: ${data['lastname']}'),
                Text('วันเกิด: ${data['birthdate']}'),
                Text('ส่วนสูง: ${data['height']}'),
                Text('น้ำหนัก: ${data['weight']}'),
                Text('โรคประจำตัว: ${data['condition']}'),
                const SizedBox(height: 40),

                // ปุ่มย้อนกลับไป FirstPage
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // กลับไปยัง FirstPage
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      'Back to First Page',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const Ownerinfo()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      backgroundColor: Colors.orange, // ใช้สีเขียวเพื่อแยกความแตกต่าง
                    ),
                    child: const Text(
                      'Go to owner information page',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ปุ่มไปยัง ThirdPage
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const Setmap()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      backgroundColor: Colors.green, // ใช้สีเขียวเพื่อแยกความแตกต่าง
                    ),
                    child: const Text(
                      'Go to Third Page',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
                // ปุ่มไปยัง ThirdPage



                const SizedBox(height: 20),

                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CameraPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      backgroundColor: Colors.blueAccent, // ใช้สีเขียวเพื่อแยกความแตกต่าง
                    ),
                    child: const Text(
                      'Go to Camera Page',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
