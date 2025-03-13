import 'package:flutter/material.dart';

class FillInfoPage extends StatefulWidget {
  final int userId; // (1) Add this field

  // (2) Update constructor to require userId
  const FillInfoPage({Key? key, required this.userId}) : super(key: key);

  @override
  _FillInfoPageState createState() => _FillInfoPageState();
}

class _FillInfoPageState extends State<FillInfoPage> {
  bool isEditing = false;
  final PageController _pageController = PageController();

  // 🔹 จำลองรูปภาพที่ได้จาก register.dart (ในอนาคตสามารถส่ง List<String> ที่มาจาก register.dart ได้)
  final List<String> imagePaths = [
    'assets/profile1.jpg',
    'assets/profile2.jpg',
    'assets/profile3.jpg',
    'assets/profile4.jpg',
    'assets/profile5.jpg',
  ];

  final TextEditingController nicknameController = TextEditingController(text: '-');
  final TextEditingController nameController = TextEditingController(text: 'ณภัทร เสียงสมบุญ');
  final TextEditingController relationController = TextEditingController(text: 'หลานของคุณ');

  @override
  Widget build(BuildContext buildContext) {
    // You can access the userId like this if needed:
    // int currentUserId = widget.userId;

    return Scaffold(
      body: Column(
        children: [
          // 🔹 แสดงรูปภาพ 5 รูปแบบเลื่อนดูได้
          Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: 250,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: imagePaths.length,
                  itemBuilder: (localCtx, index) {
                    return Image.asset(
                      imagePaths[index], // 🔹 ใช้ภาพจาก List
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
              // 🔹 ปุ่มย้อนกลับ
              Positioned(
                top: 40,
                left: 16,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              // 🔹 ปุ่มลำโพง
              Positioned(
                top: 40,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.volume_up, color: Colors.white, size: 30),
                  onPressed: () {
                    // TODO: ใส่ฟังก์ชันอ่านออกเสียง
                  },
                ),
              ),
            ],
          ),

          // 🔹 แสดง indicator บอกว่ากำลังดูรูปที่เท่าไร
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(imagePaths.length, (index) {
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (animCtx, child) {
                    double selected = _pageController.hasClients ? _pageController.page ?? 0 : 0;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: (index == selected.round()) ? 12 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (index == selected.round()) ? Colors.blue : Colors.grey,
                      ),
                    );
                  },
                );
              }),
            ),
          ),

          // 🔹 ส่วนข้อมูล
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔹 หัวข้อ "ข้อมูล" อยู่ตรงกลาง + ปุ่มแก้ไขอยู่ขวา
                  Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            'ข้อมูล',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(isEditing ? Icons.check : Icons.edit, color: Colors.blue),
                        onPressed: () {
                          setState(() {
                            isEditing = !isEditing;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 🔹 ช่องข้อมูลที่สามารถแก้ไขได้
                  _buildEditableField('ชื่อเล่น', nicknameController, isEditing),
                  _buildEditableField('ชื่อ', nameController, isEditing),
                  _buildEditableField('ความสัมพันธ์', relationController, isEditing),

                  const Spacer(),

                  // 🔹 ปุ่ม "ยืนยัน"
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: บันทึกข้อมูล (ใช้ widget.userId เพื่ออัปเดตตารางใน Database)
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'ยืนยัน',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// **📌 Widget ช่องข้อมูลที่แก้ไขได้เมื่อกดไอคอนดินสอ**
  Widget _buildEditableField(String label, TextEditingController controller, bool isEditable) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label :',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: controller,
            enabled: isEditable, // 🔹 เปิดให้แก้ไขเมื่อกดปุ่มดินสอ
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
