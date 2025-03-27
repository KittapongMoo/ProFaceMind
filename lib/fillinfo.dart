import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'camera.dart';

class FillInfoPage extends StatefulWidget {
  final int userId; // (1) Add this field

  // (2) Update constructor to require userId
  const FillInfoPage({Key? key, required this.userId}) : super(key: key);

  @override
  _FillInfoPageState createState() => _FillInfoPageState();
}

class _FillInfoPageState extends State<FillInfoPage> {
  bool isEditing = true;
  final PageController _pageController = PageController();

  List<String> imagePaths = [];

  final TextEditingController nicknameController =
      TextEditingController(text: '');
  final TextEditingController nameController = TextEditingController(text: '');
  final TextEditingController relationController =
      TextEditingController(text: '');

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'facemind.db');
    final db = await openDatabase(path);

    // Fetch user data
    final userResult = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [widget.userId],
    );

    if (userResult.isNotEmpty) {
      final user = userResult.first;
      nicknameController.text = user['nickname'] as String? ?? '-';
      nameController.text = user['name'] as String? ?? '';
      relationController.text = user['relation'] as String? ?? '';

      List<dynamic> faceVector = jsonDecode(user['face_vector'] as String);

      print('🆔 User ID: ${widget.userId}');
      print('🙋 Nickname: ${nicknameController.text}');
      print('🙋 Name: ${nameController.text}');
      print('🙋 Relation: ${relationController.text}');
      print('📷 Primary Image: ${user['primary_image']}');
      print('🧬 Face Vector: $faceVector');
    } else {
      print('❌ No user found with ID: ${widget.userId}');
    }

    // 🔴 CLEARLY FETCH ONLY IMAGES WITH THE CURRENT USER ID
    final imageResult = await db.query(
      'user_images',
      where: 'user_id = ?',
      whereArgs: [widget.userId],
    );

    setState(() {
      imagePaths = imageResult.map((e) => e['image_path'] as String).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // You can access the userId like this if needed:
    // int currentUserId = widget.userId;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // 🔝 รูปภาพส่วนบน
                      Stack(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 250,
                            child: imagePaths.isNotEmpty
                                ? PageView.builder(
                              controller: _pageController,
                              itemCount: imagePaths.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FullImagePage(
                                          imagePath: imagePaths[index],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Image.file(
                                    File(imagePaths[index]),
                                    fit: BoxFit.cover,
                                  ),
                                );
                              },
                            )
                                : const Center(child: CircularProgressIndicator()),
                          ),
                          Positioned(
                            top: 40,
                            left: 16,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back,
                                  color: Colors.white, size: 30),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),

                      // 🔘 Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(imagePaths.length, (index) {
                            return AnimatedBuilder(
                              animation: _pageController,
                              builder: (context, child) {
                                double selected = _pageController.hasClients
                                    ? _pageController.page ?? 0
                                    : 0;
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: (index == selected.round()) ? 12 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: (index == selected.round())
                                        ? Colors.blue
                                        : Colors.grey,
                                  ),
                                );
                              },
                            );
                          }),
                        ),
                      ),

                      // 🔽 เนื้อหาข้อมูล
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
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        'ข้อมูล',
                                        style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _buildEditableField('ชื่อเล่น', nicknameController, isEditing),
                              _buildEditableField('ชื่อ', nameController, isEditing),
                              _buildEditableField('ความสัมพันธ์', relationController, isEditing),

                              const SizedBox(height: 20),

                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final db = await openDatabase(
                                        join(await getDatabasesPath(), 'facemind.db'));
                                    await db.update(
                                      'users',
                                      {
                                        'nickname': nicknameController.text,
                                        'name': nameController.text,
                                        'relation': relationController.text,
                                      },
                                      where: 'id = ?',
                                      whereArgs: [widget.userId],
                                    );
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (context) => const CameraPage()),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
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
                ),
              ),
            );
          },
        ),
      ),
    );

  }

  /// **📌 Widget ช่องข้อมูลที่แก้ไขได้เมื่อกดไอคอนดินสอ**
  Widget _buildEditableField(
      String label, TextEditingController controller, bool isEditable) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label :',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
