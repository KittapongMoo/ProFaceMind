import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class PersonInfoPage extends StatefulWidget {
  final int userId;
  const PersonInfoPage({Key? key, required this.userId}) : super(key: key);

  @override
  _PersonInfoPageState createState() => _PersonInfoPageState();
}

class _PersonInfoPageState extends State<PersonInfoPage> {
  bool isEditing = false;
  final PageController _pageController = PageController();
  List<String> imagePaths = [];

  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController relationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<Database> _getDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'facemind.db');
    return openDatabase(path, version: 2);
  }

  Future<void> _loadUserData() async {
    final db = await _getDatabase();
    final userResult = await db.query('users', where: 'id = ?', whereArgs: [widget.userId]);

    if (userResult.isNotEmpty) {
      final user = userResult.first;
      nicknameController.text = user['nickname'] as String? ?? '-';
      nameController.text = user['name'] as String? ?? '';
      relationController.text = user['relation'] as String? ?? '';
    }

    final imageResult = await db.query('user_images', where: 'user_id = ?', whereArgs: [widget.userId]);

    setState(() {
      imagePaths = imageResult.map((e) => e['image_path'] as String).toList();
    });
  }

  Future<void> _updateUserData() async {
    final db = await _getDatabase();
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
    setState(() {
      isEditing = false;
    });
  }

  Widget _buildEditableField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label :', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            enabled: isEditing,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[200],
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // ✅ รูปภาพสูง 60% ของหน้าจอ
          SizedBox(
            height: screenHeight * 0.6,
            child: imagePaths.isNotEmpty
                ? PageView.builder(
              controller: _pageController,
              itemCount: imagePaths.length,
              itemBuilder: (context, index) {
                return Image.file(
                  File(imagePaths[index]),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                );
              },
            )
                : const Center(child: CircularProgressIndicator()),
          ),

          // ✅ Panel ซ้อนบนรูป
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              constraints: BoxConstraints(
                minHeight: screenHeight * 0.45,
                maxHeight: screenHeight * 0.55,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imagePaths.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
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
                                    color: (index == selected.round()) ? Colors.blue : Colors.grey,
                                  ),
                                );
                              },
                            );
                          }),
                        ),
                      ),
                    Stack(
                      children: [
                        const Center(
                          child: Text(
                            "ข้อมูล",
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            icon: Icon(isEditing ? Icons.check : Icons.edit),
                            onPressed: () {
                              if (isEditing) {
                                _updateUserData();
                              } else {
                                setState(() => isEditing = true);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildEditableField("ชื่อเล่น", nicknameController),
                    _buildEditableField("ชื่อ", nameController),
                    _buildEditableField("ความสัมพันธ์", relationController),
                    const SizedBox(height: 20),
                    if (isEditing)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _updateUserData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("ยืนยัน", style: TextStyle(fontSize: 18, color: Colors.white)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ✅ ปุ่มย้อนกลับ
          Positioned(
            top: 40,
            left: 16,
            child: FloatingActionButton(
              onPressed: () => Navigator.pop(context, true),
              backgroundColor: Colors.white,
              shape: const CircleBorder(),
              child: const Icon(Icons.arrow_back, color: Colors.black),
            ),
          ),

          // ✅ ปุ่มลำโพง
          Positioned(
            top: 40,
            right: 16,
            child: FloatingActionButton(
              onPressed: () {
                // TODO: add speaker functionality
              },
              backgroundColor: Colors.white,
              shape: const CircleBorder(),
              child: const Icon(Icons.volume_up, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}
