import 'package:flutter/material.dart';

class SetPhoneNumber extends StatefulWidget {
  const SetPhoneNumber({super.key});

  @override
  _SetPhoneNumberState createState() => _SetPhoneNumberState();
}

class _SetPhoneNumberState extends State<SetPhoneNumber> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // ✅ ป้องกัน UI ถูกบีบโดยคีย์บอร์ด
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, // ✅ ลากเพื่อปิดคีย์บอร์ด
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.more_horiz, size: 40, color: Colors.blue),
                      SizedBox(height: 10),
                      Text(
                        "ตั้งค่าเบอร์โทรศัพท์ฉุกเฉินของคุณ",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        "กรุณาใส่เบอร์โทรศัพท์บุคคลใกล้ชิดของคุณที่สามารถติดต่อได้หากเกิดเหตุ",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ✅ ช่องกรอกชื่อ
                const Text("ชื่อ :", style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: "กรุณาระบุชื่อ...",
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                // ✅ ช่องกรอกความสัมพันธ์
                const Text("ความสัมพันธ์ :", style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(
                  controller: _relationController,
                  decoration: InputDecoration(
                    hintText: "กรุณาระบุความสัมพันธ์...",
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                // ✅ ช่องกรอกเบอร์โทร
                const Text("เบอร์โทร :", style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: "กรอกเบอร์โทร...",
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),

                // ✅ ปุ่มบันทึกข้อมูล
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // ✅ บันทึกข้อมูล (เพิ่มฟังก์ชันนี้ตามที่ต้องการ)
                      print("ชื่อ: ${_nameController.text}, ความสัมพันธ์: ${_relationController.text}, เบอร์โทร: ${_phoneController.text}");
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text("เริ่มต้นการใช้งาน", style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
