import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'SecondPage.dart';

class FirstPage extends StatefulWidget {
  @override
  _FirstPageState createState() => _FirstPageState();
}

class _FirstPageState extends State<FirstPage> {
  // Controllers for input fields
  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController firstnameController = TextEditingController();
  final TextEditingController lastnameController = TextEditingController();
  final TextEditingController birthdateController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController conditionController = TextEditingController();

  // Fetch and display saved information
  Future<void> checkSavedInformation() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = {
      'ชื่อเล่น': prefs.getString('nickname') ?? 'ไม่พบข้อมูล',
      'ชื่อจริง': prefs.getString('firstname') ?? 'ไม่พบข้อมูล',
      'นามสกุล': prefs.getString('lastname') ?? 'ไม่พบข้อมูล',
      'วันเกิด': prefs.getString('birthdate') ?? 'ไม่พบข้อมูล',
      'ส่วนสูง': prefs.getString('height') ?? 'ไม่พบข้อมูล',
      'น้ำหนัก': prefs.getString('weight') ?? 'ไม่พบข้อมูล',
      'โรคประจำตัว': prefs.getString('condition') ?? 'ไม่พบข้อมูล',
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ข้อมูลที่บันทึกไว้'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: savedData.entries
              .map((entry) => Text('${entry.key}: ${entry.value}'))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  // Save input data to SharedPreferences
  Future<void> saveInformation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nickname', nicknameController.text.trim());
    await prefs.setString('firstname', firstnameController.text.trim());
    await prefs.setString('lastname', lastnameController.text.trim());
    await prefs.setString('birthdate', birthdateController.text.trim());
    await prefs.setString('height', heightController.text.trim());
    await prefs.setString('weight', weightController.text.trim());
    await prefs.setString('condition', conditionController.text.trim());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ข้อมูลถูกบันทึกเรียบร้อยแล้ว!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ข้อมูล',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await saveInformation();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SecondPage()),
              );
            },
            child: const Text(
              'ยืนยัน',
              style: TextStyle(fontSize: 16, color: Colors.blue),
            ),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildInputField('ชื่อเล่น', 'กรอกชื่อเล่น', nicknameController),
              buildInputField('ชื่อจริง', 'กรอกชื่อจริง', firstnameController),
              buildInputField('นามสกุล', 'กรอกนามสกุล', lastnameController),
              buildInputField('วันเกิด', 'กรอกวันเกิด', birthdateController),
              buildInputField('ส่วนสูง', 'กรอกส่วนสูง', heightController),
              buildInputField('น้ำหนัก', 'กรอกน้ำหนัก', weightController),
              buildInputField('โรคประจำตัว', 'กรอกโรคประจำตัว', conditionController),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: checkSavedInformation,
                child: const Text('ตรวจสอบข้อมูลที่บันทึกไว้'),
              ),
              const SizedBox(height: 16),
              const Text(
                'รูป :',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.asset(
                    'assets/profile.jpg',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build input field widget
  Widget buildInputField(String label, String hintText, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label :',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hintText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              filled: true,
              fillColor: Colors.grey[200],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    nicknameController.dispose();
    firstnameController.dispose();
    lastnameController.dispose();
    birthdateController.dispose();
    heightController.dispose();
    weightController.dispose();
    conditionController.dispose();
    super.dispose();
  }
}
