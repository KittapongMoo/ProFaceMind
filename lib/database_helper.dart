import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'facemind.db');

    return await openDatabase(path, version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
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

    await db.execute('''
      CREATE TABLE user_vectors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        vector TEXT,
        FOREIGN KEY(user_id) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        matched_at TEXT,
        face_image BLOB
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE users ADD COLUMN primary_image TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_vectors (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER,
          vector TEXT,
          FOREIGN KEY(user_id) REFERENCES users(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER,
          matched_at TEXT,
          face_image BLOB
        )
      ''');

      List<Map> columns = await db.rawQuery("PRAGMA table_info(history)");
      bool hasFaceImage = columns.any((col) => col['name'] == 'face_image');
      if (!hasFaceImage) {
        await db.execute("ALTER TABLE history ADD COLUMN face_image BLOB");
      }
    }
  }
}
