import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// A page that shows all registered people in a 3-column grid,
/// displaying each person's primary face image and nickname.
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
      // If you have onCreate or onUpgrade, include them here.
    );
  }

  /// Loads the user records from the 'users' table.
  /// We'll only need 'id', 'nickname', and 'primary_image'.
  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final db = await _getDatabase();
    return db.query(
      'users',
      columns: ['id', 'nickname', 'primary_image'],
      orderBy: 'id DESC',
    );
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
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Error state
          if (snapshot.hasError) {
            return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
          }
          // No data or empty
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('ยังไม่มีการลงทะเบียนผู้ใช้'));
          }

          // We have data
          final users = snapshot.data!;

          // Build a GridView with 3 columns
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              itemCount: users.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,    // 3 columns
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.7, // Adjust for circle + nickname text
              ),
              itemBuilder: (context, index) {
                final user = users[index];
                final nickname = user['nickname'] ?? '';
                final primaryImage = user['primary_image'] as String?;

                // Build circle avatar or placeholder
                Widget avatarWidget;
                if (primaryImage != null &&
                    primaryImage.isNotEmpty &&
                    File(primaryImage).existsSync()) {
                  avatarWidget = CircleAvatar(
                    radius: 40,
                    backgroundImage: FileImage(File(primaryImage)),
                  );
                } else {
                  // If no image, show a gray circle with an icon
                  avatarWidget = const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, color: Colors.white),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    avatarWidget,
                    const SizedBox(height: 8),
                    Text(
                      nickname,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
