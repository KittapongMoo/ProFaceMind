// ... ส่วน import คงเดิม
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'personinfo.dart';

class AllRegisterPage extends StatefulWidget {
  const AllRegisterPage({Key? key}) : super(key: key);

  @override
  State<AllRegisterPage> createState() => _AllRegisterPageState();
}

class _AllRegisterPageState extends State<AllRegisterPage> {
  late Future<List<Map<String, dynamic>>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
  }

  Future<Database> _getDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'facemind.db');
    return openDatabase(path, version: 2);
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final db = await _getDatabase();
    return await db.rawQuery('''
      SELECT 
        u.id, 
        u.nickname, 
        CASE 
          WHEN u.primary_image IS NOT NULL AND u.primary_image <> '' 
          THEN u.primary_image 
          ELSE MIN(ui.image_path)
        END AS first_image
      FROM users u
      LEFT JOIN user_images ui ON ui.user_id = u.id
      GROUP BY u.id
      ORDER BY u.id DESC
    ''');
  }

  Future<void> _deleteUser(int userId) async {
    final db = await _getDatabase();
    // Optionally, you might also delete related images from the file system here.
    await db.delete('user_images', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);

    // Reload the user list.
    setState(() {
      _usersFuture = _loadUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 60),
              const Center(
                child: Text(
                  'ผู้คน',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(1, 2),
                        blurRadius: 3,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _usersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(
                          child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('ยังไม่มีการลงทะเบียนผู้ใช้'));
                    }

                    final users = snapshot.data!;

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: GridView.builder(
                        itemCount: users.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.75,
                        ),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final nickname = user['nickname'] ?? '';
                          final firstImage = user['first_image'] as String?;
                          final userId = user['id'] as int;

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PersonInfoPage(userId: userId),
                                ),
                              ).then((result) {
                                if (result == true) {
                                  setState(() {
                                    _usersFuture = _loadUsers();
                                  });
                                }
                              });
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (firstImage != null &&
                                        firstImage.isNotEmpty &&
                                        File(firstImage).existsSync())
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(30),
                                        child: Image.file(
                                          File(firstImage),
                                          width: 105,
                                          height: 105,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 105,
                                        height: 105,
                                        decoration: BoxDecoration(
                                          color: Colors.grey,
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                        child: const Icon(Icons.person, color: Colors.white, size: 48),
                                      ),
                                    const SizedBox(height: 8),
                                    Text(
                                      nickname.isNotEmpty ? nickname : 'ไม่มีข้อมูล',
                                      style: const TextStyle(fontSize: 16),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                // Delete button at top right corner, raised with elevation=10.
                                Positioned(
                                  top: -18,
                                  right: -10,
                                  child: Material(
                                    elevation: 10,
                                    shape: const CircleBorder(),
                                    color: Colors.white,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        // Confirm deletion (optional)
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            return AlertDialog(
                                              title: const Text('Confirm Deletion'),
                                              content: const Text('Are you sure you want to delete this user?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () async {
                                                    Navigator.pop(context);
                                                    await _deleteUser(userId);
                                                  },
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // 🔙 Back Button
          Positioned(
            top: 40,
            left: 16,
            child: FloatingActionButton(
              onPressed: () => Navigator.pop(context),
              backgroundColor: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              child: const Icon(Icons.arrow_back, color: Colors.black),
            ),
          ),

          // ➕ Next Page Placeholder
          Positioned(
            top: 40,
            right: 16,
            child: FloatingActionButton(
              onPressed: () {
                // TODO: Add navigation
              },
              backgroundColor: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              child: const Icon(Icons.access_time, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
