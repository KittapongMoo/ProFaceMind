import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'camera.dart'; // For potential navigation back to CameraPage

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

      print('User ID: ${widget.userId}');
      print('Nickname: ${nicknameController.text}');
      print('Name: ${nameController.text}');
      print('Relation: ${relationController.text}');
      print('Primary Image: ${user['primary_image']}');
    } else {
      print('No user found with ID: ${widget.userId}');
    }

    // Fetch only images with the current user id from user_images.
    final imageResult = await db.query(
      'user_images',
      where: 'user_id = ?',
      whereArgs: [widget.userId],
    );

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
    // Show SnackBar to indicate data saved.
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // When the user presses the system back button,
      // we pop with true to indicate changes were made.
      onWillPop: () async {
        Navigator.pop(context, true);
        return false;
      },
      child: Scaffold(
        body: Column(
          children: [
            // Images at the top (PageView)
            Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 250,
                  child: imagePaths.isNotEmpty
                      ? PageView.builder(
                    controller: _pageController,
                    itemCount: imagePaths.length,
                    itemBuilder: (localCtx, index) {
                      return GestureDetector(
                        onTap: () {
                          // Navigate to full image view when tapped.
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullImagePage(
                                  imagePath: imagePaths[index]),
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
                // Back button overlay
                Positioned(
                  top: 40,
                  left: 16,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context, true), // Return true
                  ),
                ),
              ],
            ),
            // Image indicator
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(imagePaths.length, (index) {
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (animCtx, child) {
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
            // Editable Information Section
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
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stack to center "ข้อมูล" with edit icon at right.
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Center(
                              child: Text(
                                'ข้อมูล',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: IconButton(
                              icon: Icon(isEditing ? Icons.check : Icons.edit),
                              onPressed: () async {
                                if (isEditing) {
                                  await _updateUserData();
                                } else {
                                  setState(() {
                                    isEditing = true;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildEditableField(
                          'ชื่อเล่น', nicknameController, isEditing),
                      _buildEditableField('ชื่อ', nameController, isEditing),
                      _buildEditableField(
                          'ความสัมพันธ์', relationController, isEditing),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField(
      String label, TextEditingController controller, bool isEditable) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: controller,
            enabled: isEditable,
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
