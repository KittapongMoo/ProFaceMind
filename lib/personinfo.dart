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
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();

  bool formValid = false;

  List<String> imagePaths = [];

  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController relationController = TextEditingController();

  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkTTSAvailability();

    nicknameController.addListener(_onTextChanged);
    nameController.addListener(_onTextChanged);
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
    var engines = await flutterTts.getEngines;
    print("🔍 เครื่องนี้รองรับ TTS engines: $engines");

    var languages = await flutterTts.getLanguages;
    print("🌐 รองรับภาษาดังนี้: $languages");
  }

  void _onTextChanged() {
    final ok = nicknameController.text.trim().isNotEmpty
        && nameController.text.trim().isNotEmpty
        && relationController.text.trim().isNotEmpty;
    if (ok != formValid) {
      setState(() => formValid = ok);
    }
  }

  Future<Database> _getDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'facemind.db');
    return openDatabase(path, version: 3);
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

  Future<void> _speakUserInfo() async {
    String text = "ชื่อเล่น ${nicknameController.text}, "
        "ชื่อ ${nameController.text}, "
        "ความสัมพันธ์ ${relationController.text}";

    print("📣 อ่านออกเสียงข้อความ: $text");

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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // รูปภาพสูง 60% (กดเพื่อดูเต็มจอ)
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
                    width: double.infinity,
                    height: double.infinity,
                  ),
                );
              },
            )
                : const Center(child: CircularProgressIndicator()),
          ),

          // Panel ข้อมูล
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
                          child: isEditing
                          // when editing: show nothing
                              ? const SizedBox.shrink()
                          // when *not* editing: show the edit pencil
                              : IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              setState(() => isEditing = true);
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
                          onPressed: formValid ? _updateUserData : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            disabledBackgroundColor: Colors.grey,  // grey when onPressed == null
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "ยืนยัน",
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),

                      ),
                  ],
                ),
              ),
            ),
          ),

          // ปุ่มย้อนกลับ
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

          // ปุ่มลำโพง
          Positioned(
            top: 40,
            right: 16,
            child: FloatingActionButton(
              onPressed: _speakUserInfo,
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
    // start on the tapped image
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
        itemBuilder: (context, pageIndex) {
          return Center(
            child: InteractiveViewer(
              child: Image.file(
                File(widget.imagePaths[pageIndex]),
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
