import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditing = false;
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _firstnameController = TextEditingController();
  final TextEditingController _lastnameController = TextEditingController();
  DateTime? _selectedDate;
  String _selectedHeight = "150 ซม.";
  String _selectedWeight = "50 กก.";
  final TextEditingController _conditionController = TextEditingController();
  String? _imagePath;
  File? _image;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _firstnameController.dispose();
    _lastnameController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  /// ✅ โหลดข้อมูลจาก SharedPreferences
  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nicknameController.text = prefs.getString('nickname') ?? '';
      _firstnameController.text = prefs.getString('firstname') ?? '';
      _lastnameController.text = prefs.getString('lastname') ?? '';
      _selectedDate = prefs.getString('birthdate') != null
          ? DateTime.parse(prefs.getString('birthdate')!)
          : null;
      _selectedHeight = prefs.getString('height') ?? "150 ซม.";
      _selectedWeight = prefs.getString('weight') ?? "50 กก.";
      _conditionController.text = prefs.getString('condition') ?? '';
      _imagePath = prefs.getString('imagePath');
      _image = _imagePath != null ? File(_imagePath!) : null;
    });
  }

  /// ✅ บันทึกข้อมูลลง SharedPreferences
  Future<void> _saveProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nickname', _nicknameController.text.trim());
    await prefs.setString('firstname', _firstnameController.text.trim());
    await prefs.setString('lastname', _lastnameController.text.trim());
    await prefs.setString('birthdate', _selectedDate?.toIso8601String() ?? '');
    await prefs.setString('height', _selectedHeight);
    await prefs.setString('weight', _selectedWeight);
    await prefs.setString('condition', _conditionController.text.trim());
    if (_image != null) {
      await prefs.setString('imagePath', _image!.path);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ข้อมูลถูกบันทึกเรียบร้อย!')),
    );

    setState(() {
      _isEditing = false; // ✅ ปิดโหมดแก้ไข
    });
  }

  /// ✅ เลือกรูปภาพจากแกลเลอรี
  Future<void> _pickImage() async {
    final status = await Permission.photos.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ต้องอนุญาตให้เข้าถึงรูปภาพ')),
      );
      return;
    }

    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _imagePath = pickedFile.path;
      });
    }
  }

  /// ✅ เลือกวันเกิดจากปฏิทิน
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'เลือกวันเกิด',
      cancelText: 'ยกเลิก',
      confirmText: 'เลือก',
      locale: const Locale('th', 'TH'),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ข้อมูลส่วนตัว"),
        actions: [
          _isEditing
              ? IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            onPressed: _saveProfileData,
          )
              : IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              setState(() {
                _isEditing = true;
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildEditableField("ชื่อเล่น", _nicknameController),
            _buildEditableField("ชื่อจริง", _firstnameController),
            _buildEditableField("นามสกุล", _lastnameController),

            _buildDatePicker(),

            _buildDropdownField(
              label: "ส่วนสูง",
              value: _selectedHeight,
              items: List.generate(101, (index) => '${150 + index} ซม.'),
              onChanged: (value) => setState(() => _selectedHeight = value!),
            ),
            _buildDropdownField(
              label: "น้ำหนัก",
              value: _selectedWeight,
              items: List.generate(101, (index) => '${50 + index} กก.'),
              onChanged: (value) => setState(() => _selectedWeight = value!),
            ),

            _buildEditableField("โรคประจำตัว", _conditionController),

            const SizedBox(height: 20),
            const Text("รูปโปรไฟล์ :", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            Center(
              child: GestureDetector(
                onTap: _isEditing ? _pickImage : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _image != null
                      ? Image.file(_image!, width: 120, height: 120, fit: BoxFit.cover)
                      : const Text("ไม่มีรูปภาพ"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ ช่องข้อมูลที่แก้ไขได้เมื่ออยู่ในโหมดแก้ไข
  Widget _buildEditableField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text("$label :", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          Expanded(
            flex: 7,
            child: _isEditing
                ? TextFormField(
              controller: controller,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            )
                : _buildReadonlyBox(controller.text),
          ),
        ],
      ),
    );
  }

  /// ✅ Widget สำหรับ DatePicker
  Widget _buildDatePicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Expanded(flex: 3, child: Text("วันเกิด :", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          Expanded(
            flex: 7,
            child: _isEditing
                ? ElevatedButton(
              onPressed: () => _selectDate(context),
              child: Text(_selectedDate != null ? "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}" : "เลือกวันเกิด"),
            )
                : _buildReadonlyBox(_selectedDate != null ? "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}" : "ไม่มีข้อมูล"),
          ),
        ],
      ),
    );
  }

  /// ✅ Widget สำหรับ Dropdown
  Widget _buildDropdownField({required String label, required String value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text("$label :", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          Expanded(flex: 7, child: _isEditing ? DropdownButtonFormField(value: value, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged) : _buildReadonlyBox(value)),
        ],
      ),
    );
  }

  Widget _buildReadonlyBox(String value) => Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: Text(value));
}
