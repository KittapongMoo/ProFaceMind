import 'package:flutter/material.dart';
import 'SecondPage.dart'; // นำเข้า SecondPage.dart

class FirstPage extends StatefulWidget {
  @override
  _FirstPageState createState() => _FirstPageState();
}

class _FirstPageState extends State<FirstPage> {
  // Controllers สำหรับแต่ละฟิลด์
  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController firstnameController = TextEditingController();
  final TextEditingController lastnameController = TextEditingController();
  final TextEditingController birthdateController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController conditionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ข้อมูล',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // นำพาไปยัง SecondPage พร้อมส่งข้อมูล
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SecondPage(),
                ),
              );
            },
            child: const Text(
              'ยืนยัน',
              style: TextStyle(
                fontSize: 16,
                color: Colors.blue,
              ),
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
              const Text(
                'รูป :',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.asset(
                    'assets/profile.jpg', // ใช้รูปภาพจาก assets
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

  Widget buildInputField(String label, String hintText, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label :',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
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
    // ล้าง TextEditingController เมื่อปิดหน้า
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
