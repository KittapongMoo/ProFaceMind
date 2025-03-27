import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'personinfo.dart'; // Import your PersonInfoPage

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

  /// Opens (or creates) the local SQLite database.
  Future<Database> _getDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'facemind.db');
    return openDatabase(
      path,
      version: 2,
    );
  }

  /// Loads the user records along with the first (oldest) image from user_images.
  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final db = await _getDatabase();
    // This query returns each user's id, nickname, and the first image.
    // If primary_image is set (non-empty) it takes precedence; otherwise, it uses the minimum image_path from user_images.
    final List<Map<String, dynamic>> results = await db.rawQuery('''
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
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ผู้คน'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
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
                childAspectRatio: 0.7,
              ),
              itemBuilder: (context, index) {
                final user = users[index];
                final nickname = user['nickname'] ?? '';
                final firstImage = user['first_image'] as String?;

                // Wrap the grid item in a GestureDetector to handle taps.
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PersonInfoPage(userId: user['id']),
                      ),
                    ).then((result) {
                      if (result == true) {
                        setState(() {
                          _usersFuture = _loadUsers();
                        });
                      }
                    });
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Use a rectangle with rounded edges for the image.
                      if (firstImage != null &&
                          firstImage.isNotEmpty &&
                          File(firstImage).existsSync())
                        ClipRRect(
                          borderRadius: BorderRadius.circular(27),
                          child: Image.file(
                            File(firstImage),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(27),
                          ),
                          child:
                          const Icon(Icons.person, color: Colors.white),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        nickname,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
