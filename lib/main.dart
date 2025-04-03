import 'package:flutter/material.dart';
import 'Ownerinfo.dart';
import 'secondpage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'register.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// Global navigator key and route observer.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// Make main() asynchronous.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the history table.
  await _initializeHistoryDatabase();
  runApp(const MyApp());
}

// This function opens your shared database and creates the history table if it does not exist.
Future<void> _initializeHistoryDatabase() async {
  final dbPath = await getDatabasesPath();
  final path = join(dbPath, 'facemind.db');
  // Open (or create) the database.
  Database db = await openDatabase(
    path,
    version: 3,
    onCreate: (Database db, int version) async {
      // Create your existing tables.
      await db.execute('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          face_vector TEXT,
          nickname TEXT,
          name TEXT,
          relation TEXT,
          primary_image TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE user_images (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER,
          image_path TEXT,
          FOREIGN KEY(user_id) REFERENCES users(id)
        )
      ''');
      // Create the history table including a face_image column as a BLOB.
      await db.execute('''
        CREATE TABLE history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER,
          matched_at TEXT,
          face_image BLOB
        )
      ''');
    },
    onOpen: (Database db) async {
      // In case the history table exists but lacks the face_image column,
      // add it via an ALTER TABLE statement.
      List<Map> columns = await db.rawQuery("PRAGMA table_info(history)");
      bool hasFaceImage = columns.any((col) => col['name'] == 'face_image');
      if (!hasFaceImage) {
        await db.execute("ALTER TABLE history ADD COLUMN face_image BLOB");
      }
    },
  );
  print('History table initialized in database at $path');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'My App',
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      debugShowCheckedModeBanner: false,
      home: const PersonalInfoPage(),
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('th', 'TH'), // Ensure Thai locale is supported.
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorObservers: [routeObserver],
    );
  }
}

class PersonalInfoPage extends StatelessWidget {
  const PersonalInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB0C4DE),
      body: Stack(
        children: [
          // Top section with large icon.
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.width * 0.6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFB0C4DE),
                    ),
                    child: Align(
                      alignment: Alignment(0, -0.5),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.circle,
                            size: MediaQuery.of(context).size.width * 0.85,
                            color: Colors.grey[400],
                          ),
                          Icon(
                            Icons.account_circle,
                            size: MediaQuery.of(context).size.width * 0.85,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom section (fixed at bottom).
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.only(top: 20, bottom: 40),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page indicator dots.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Title text.
                  const Text(
                    "ข้อมูลส่วนตัว",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Description text.
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40.0),
                    child: Text(
                      "กรุณากรอกข้อมูลส่วนตัวของผู้ใช้เพื่อเป็นข้อมูลในการระบุตัวตนของเจ้าของเครื่อง",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Button.
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SecondPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007BFF),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 80, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "กรอกข้อมูลเลย",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
