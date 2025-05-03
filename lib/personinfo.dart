import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
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
  bool formValid = false;
  bool _nameExists = false; // ← new

  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();

  List<String> imagePaths = [];

  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController nameController     = TextEditingController();
  final TextEditingController relationController = TextEditingController();

  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkTTSAvailability();

    nicknameController.addListener(_onTextChanged);
    nameController.addListener(() {
      _checkNameExists();  // ← new
      _onTextChanged();
    });
    relationController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    nicknameController.removeListener(_onTextChanged);
    nameController.removeListener(_onTextChanged);
    relationController.removeListener(_onTextChanged);
    super.dispose();
  }

  Future<void> _checkTTSAvailability() async {
    var engines   = await flutterTts.getEngines;
    var languages = await flutterTts.getLanguages;
    print("🔍 Engines: $engines");
    print("🌐 Languages: $languages");
  }

  void _onTextChanged() {
    final ok = nicknameController.text.trim().isNotEmpty
        && nameController.text.trim().isNotEmpty
        && relationController.text.trim().isNotEmpty
        && !_nameExists;                // ← block duplicates
    if (ok != formValid) {
      setState(() => formValid = ok);
    }
  }

  Future<Database> _getDatabase() async {
    final dbPath = await getDatabasesPath();
    final path   = join(dbPath, 'facemind.db');
    return openDatabase(path, version: 3);
  }

  Future<void> _checkNameExists() async {
    final db = await _getDatabase();
    final rows = await db.query(
      'users',
      where: 'name = ? AND id != ?',
      whereArgs: [nameController.text.trim(), widget.userId],
    );
    final exists = rows.isNotEmpty;
    if (exists != _nameExists) {
      setState(() => _nameExists = exists);
    }
  }

  Future<void> _loadUserData() async {
    final db = await _getDatabase();

    // load this user
    final userResult = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [widget.userId],
    );
    if (userResult.isNotEmpty) {
      final user = userResult.first;
      nicknameController.text = user['nickname'] as String? ?? '';
      nameController.text     = user['name']     as String? ?? '';
      relationController.text = user['relation'] as String? ?? '';
    }

    // load images
    final imageResult = await db.query(
      'user_images',
      where: 'user_id = ?',
      whereArgs: [widget.userId],
    );
    setState(() {
      imagePaths = imageResult.map((e) => e['image_path'] as String).toList();
    });
  }

  Future<void> _updateUserData(BuildContext context) async {
    // 1. Make sure your Form is valid
    if (!_formKey.currentState!.validate()) return;

    final db = await _getDatabase();

    // 2. Check for any other user with the same name
    final dup = await db.query(
      'users',
      where: 'name = ? AND id != ?',
      whereArgs: [nameController.text.trim(), widget.userId],
    );
    if (dup.isNotEmpty) {
      // 3. Only call context if still mounted
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ชื่อนี้มีอยู่ในระบบแล้ว')),
      );
      return;
    }

    // 4. All clear — write to the database
    await db.update(
      'users',
      {
        'nickname': nicknameController.text.trim(),
        'name':     nameController.text.trim(),
        'relation': relationController.text.trim(),
      },
      where: 'id = ?',
      whereArgs: [widget.userId],
    );

    // 5. Finally update your UI
    if (!mounted) return;
    setState(() => isEditing = false);
  }

  Future<void> _speakUserInfo() async {
    String text = "ชื่อเล่น ${nicknameController.text}, "
        "ชื่อ ${nameController.text}, "
        "ความสัมพันธ์ ${relationController.text}";
    await flutterTts.setLanguage("th-TH");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.speak(text);
  }

  Widget _buildEditableField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            enabled: isEditing,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'กรุณากรอกข้อมูล $label';
              }
              return null;
            },
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

  Widget _buildNameField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ชื่อ:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          TextFormField(
            controller: nameController,
            enabled: isEditing,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'กรุณากรอกข้อมูล ชื่อ';
              }
              if (_nameExists) {
                return 'ชื่อนี้มีอยู่ในระบบแล้ว';
              }
              return null;
            },
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
          if (_nameExists)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: Text(
                'ชื่อนี้มีอยู่ในระบบแล้ว',
                style: TextStyle(color: Colors.red[700], fontSize: 12),
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
          // Image pager (60%)
          SizedBox(
            height: screenHeight * 0.6,
            child: imagePaths.isNotEmpty
                ? PageView.builder(
              controller: _pageController,
              itemCount: imagePaths.length,
              itemBuilder: (c, i) => GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => FullImagePage(
                    imagePaths: imagePaths,
                    initialIndex: i,
                  ),
                )),
                child: Image.file(
                  File(imagePaths[i]),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            )
                : const Center(child: CircularProgressIndicator()),
          ),

          // Info panel
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
                boxShadow: [ BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2) ],
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
                          children: List.generate(imagePaths.length, (i) {
                            double selected = _pageController.hasClients
                                ? (_pageController.page ?? 0)
                                : 0;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: (i == selected.round()) ? 12 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (i == selected.round()) ? Colors.blue : Colors.grey,
                              ),
                            );
                          }),
                        ),
                      ),
                    Stack(
                      children: [
                        const Center(
                          child: Text("ข้อมูล", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        ),
                        if (!isEditing)
                          Positioned(
                            right: 0, top: 0,
                            child: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => setState(() => isEditing = true),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildEditableField("ชื่อเล่น", nicknameController),
                    _buildNameField(),                   // ← replaced
                    _buildEditableField("ความสัมพันธ์", relationController),

                    const SizedBox(height: 20),
                    if (isEditing)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: formValid
                              ? () => _updateUserData(context)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            disabledBackgroundColor: Colors.grey,
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

          // Back button
          Positioned(
            top: 40,
            left: 16,
            child: FloatingActionButton(
              onPressed: () => Navigator.pop(context, true),
              backgroundColor: Colors.white,
              shape: const CircleBorder(),      // ← forces perfect circle
              child: const Icon(Icons.arrow_back, color: Colors.black),
              heroTag: 'backBtn',
            ),
          ),

// Speak button
          Positioned(
            top: 40,
            right: 16,
            child: FloatingActionButton(
              onPressed: _speakUserInfo,
              backgroundColor: Colors.white,
              shape: const CircleBorder(),      // ← forces perfect circle
              child: const Icon(Icons.volume_up, color: Colors.blue),
              heroTag: 'speakBtn',
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
  const FullImagePage({Key? key, required this.imagePaths, required this.initialIndex}) : super(key: key);
  @override _FullImagePageState createState() => _FullImagePageState();
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
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 32, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imagePaths.length,
        itemBuilder: (c, i) => Center(
          child: InteractiveViewer(
            child: Image.file(
              File(widget.imagePaths[i]),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
