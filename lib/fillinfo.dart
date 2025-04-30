import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'camera.dart';
import 'database_helper.dart';

class FillInfoPage extends StatefulWidget {
  final int userId;

  const FillInfoPage({Key? key, required this.userId}) : super(key: key);

  @override
  _FillInfoPageState createState() => _FillInfoPageState();
}

class _FillInfoPageState extends State<FillInfoPage> {
  bool isEditing = true;
  bool _isFormValid = false;
  final PageController _pageController = PageController();

  List<String> imagePaths = [];

  final TextEditingController nicknameController = TextEditingController(text: '');
  final TextEditingController nameController = TextEditingController(text: '');
  final TextEditingController relationController = TextEditingController(text: '');

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final db = await DatabaseHelper().database;
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
      }

      final imageResult = await db.query(
        'user_images',
        where: 'user_id = ?',
        whereArgs: [widget.userId],
      );

      setState(() {
        imagePaths = imageResult.map((e) => e['image_path'] as String).toList();
      });
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  /// Delete the unconfirmed user and all related images
  Future<void> _deleteCurrentUser() async {
    final db = await DatabaseHelper().database;
    await db.delete(
      'user_images',
      where: 'user_id = ?',
      whereArgs: [widget.userId],
    );
    await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [widget.userId],
    );
  }

  void _checkFormValidity() {
    final isValid = nicknameController.text.trim().isNotEmpty &&
        nameController.text.trim().isNotEmpty &&
        relationController.text.trim().isNotEmpty;
    setState(() {
      _isFormValid = isValid;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return WillPopScope(
      onWillPop: () async {
        await _deleteCurrentUser();
        return true; // allow pop
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Top images (60%)
            SizedBox(
              height: screenHeight * 0.6,
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
                          builder: (_) => FullImagePage(
                            imagePaths: imagePaths,
                            initialIndex: index,
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

            // Back FAB
            Positioned(
              top: 40,
              left: 16,
              child: FloatingActionButton(
                onPressed: () async {
                  await _deleteCurrentUser();
                  Navigator.pop(context);
                },
                backgroundColor: Colors.white,
                shape: const CircleBorder(),
                child: const Icon(Icons.arrow_back, color: Colors.black),
              ),
            ),

            // Bottom panel
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2),
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
                      // Page indicator
                      if (imagePaths.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(imagePaths.length, (index) {
                              return AnimatedBuilder(
                                animation: _pageController,
                                builder: (context, child) {
                                  final selected =
                                  _pageController.hasClients ? (_pageController.page ?? 0) : 0;
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    width: index == selected.round() ? 12 : 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: index == selected.round() ? Colors.blue : Colors.grey,
                                    ),
                                  );
                                },
                              );
                            }),
                          ),
                        ),

                      const Center(
                        child: Text(
                          'ข้อมูล',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),

                      const SizedBox(height: 16),

                      _buildEditableField('ชื่อเล่น', nicknameController, isEditing),
                      _buildEditableField('ชื่อ', nameController, isEditing),
                      _buildEditableField('ความสัมพันธ์', relationController, isEditing),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: !_isFormValid
                              ? null
                              : () async {
                            final db = await DatabaseHelper().database;
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
                              MaterialPageRoute(builder: (_) => const CameraPage()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('ยืนยัน', style: TextStyle(fontSize: 18, color: Colors.white)),
                        ),
                      ),

                      const SizedBox(height: 20),
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

  Widget _buildEditableField(String label, TextEditingController controller, bool isEditable) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label :', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          TextField(
            controller: controller,
            enabled: isEditable,
            onChanged: (_) => _checkFormValidity(),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[200],
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }
}

class FullImagePage extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;

  const FullImagePage({
    Key? key,
    required this.imagePaths,
    required this.initialIndex,
  }) : super(key: key);

  @override
  _FullImagePageState createState() => _FullImagePageState();
}

class _FullImagePageState extends State<FullImagePage> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 32, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imagePaths.length,
        itemBuilder: (context, idx) {
          return Center(
            child: InteractiveViewer(
              child: Image.file(
                File(widget.imagePaths[idx]),
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}