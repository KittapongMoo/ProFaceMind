import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'SecondPage.dart';

class Ownerinfo extends StatefulWidget {
  const Ownerinfo({Key? key}) : super(key: key);

  @override
  _OwnerinfoState createState() => _OwnerinfoState();
}

class _OwnerinfoState extends State<Ownerinfo> {
  // Global key for the form
  final _formKey = GlobalKey<FormState>();

  // Controllers for input fields
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _firstnameController = TextEditingController();
  final TextEditingController _lastnameController = TextEditingController();
  final TextEditingController _conditionController = TextEditingController();

  // State variables
  File? _image;
  DateTime? _selectedDate;
  String _selectedHeight = "150 ซม.";
  String _selectedWeight = "50 กก.";
  bool _isLoading = false;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _loadSavedInformation(); // Load saved data when opening the app
  }

  // Dispose controllers when not needed
  @override
  void dispose() {
    _nicknameController.dispose();
    _firstnameController.dispose();
    _lastnameController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  // Method to pick image from gallery
  Future<void> _pickImage() async {
    debugPrint("pickImage() called");

    final status = await Permission.photos.request();
    if (!status.isGranted) {
      debugPrint("Permission denied. Showing snackbar.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ต้องอนุญาตให้เข้าถึงรูปภาพก่อน')),
      );
      return;
    }

    try {
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        debugPrint("Image selected: ${pickedFile.path}");

        // Save image path in SharedPreferences first
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('imagePath', pickedFile.path);

        // Update UI state after saving
        setState(() {
          _image = File(pickedFile.path);
        });
      } else {
        debugPrint("No image selected.");
      }


    } catch (e) {
      debugPrint("Error picking image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  // Method to select date
  Future<void> _selectDate(BuildContext context) async {
    if (!mounted) return; // Ensure the widget is still in the tree

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'เลือกวันเกิด',
      cancelText: 'ยกเลิก',
      confirmText: 'เลือก',
      locale: const Locale('th', 'TH'), // Set locale to Thai
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light(), // Ensure correct styling
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }


  // Method to save information to SharedPreferences
  Future<void> _saveInformation() async {
    if (!_formKey.currentState!.validate()) {
      return; // If form is not valid, do not proceed
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance(); // Define prefs here

      await prefs.setString('nickname', _nicknameController.text.trim());
      await prefs.setString('firstname', _firstnameController.text.trim());
      await prefs.setString('lastname', _lastnameController.text.trim());
      await prefs.setString(
          'birthdate', _selectedDate?.toIso8601String() ?? '');
      await prefs.setString('height', _selectedHeight);
      await prefs.setString('weight', _selectedWeight);
      await prefs.setString('condition', _conditionController.text.trim());

      // Save image path if an image is selected
      if (_image != null) {
        await prefs.setString('imagePath', _image!.path);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ข้อมูลถูกบันทึกเรียบร้อยแล้ว!')),
      );

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SecondPage()),
      );
    } catch (e) {
      debugPrint("Error saving information: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดขณะบันทึกข้อมูล: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  Future<void> _loadSavedInformation() async {
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

  void _showInfoDialog() {
    // Ensure the data is loaded before showing the dialog
    if (_nicknameController.text.isEmpty || _firstnameController.text.isEmpty || _lastnameController.text.isEmpty) {
      // If the information is not loaded, prompt the user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ข้อมูลยังไม่ถูกบันทึก!')),
      );
      return;
    }

    // Create the dialog with the saved information
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ข้อมูลผู้ใช้'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ชื่อเล่น: ${_nicknameController.text}'),
                Text('ชื่อจริง: ${_firstnameController.text}'),
                Text('นามสกุล: ${_lastnameController.text}'),
                Text('วันเกิด: ${_selectedDate != null ? "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}" : 'ไม่ได้ระบุ'}'),
                Text('ส่วนสูง: $_selectedHeight'),
                Text('น้ำหนัก: $_selectedWeight'),
                Text('โรคประจำตัว: ${_conditionController.text.isNotEmpty ? _conditionController.text : 'ไม่มีข้อมูล'}'),
                _image != null
                    ? Image.file(_image!, width: 100, height: 100, fit: BoxFit.cover)
                    : const Text('ไม่มีรูปภาพโปรไฟล์'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('ปิด'),
            ),
          ],
        );
      },
    );
  }




  Widget _buildInputField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label :',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200], // พื้นหลังสีเทาอ่อน
              borderRadius: BorderRadius.circular(20), // ทำให้ขอบโค้งมน
            ),
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              readOnly: readOnly, // ใช้สำหรับช่องที่ไม่ต้องการให้แก้ไข
              decoration: const InputDecoration(
                border: InputBorder.none, // ไม่มีขอบ
                contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              ),
              validator: isRequired
                  ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณากรอก $label';
                }
                return null;
              }
                  : null,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label :',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200], // พื้นหลังสีเทาอ่อน
              borderRadius: BorderRadius.circular(20), // ขอบโค้งมน
            ),
            child: DropdownButtonFormField<String>(
              value: value,
              decoration: const InputDecoration(
                border: InputBorder.none, // ไม่มีกรอบ
                contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              ),
              isExpanded: true,
              onChanged: onChanged,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, style: const TextStyle(fontSize: 16)),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildDatePickerField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label :',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[200], // พื้นหลังสีเทาอ่อน
                borderRadius: BorderRadius.circular(20), // ขอบโค้งมน
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    value.isNotEmpty ? value : 'เลือก $label',
                    style: TextStyle(
                        fontSize: 16,
                        color: value.isNotEmpty ? Colors.black : Colors.grey
                    ),
                  ),
                  const Icon(Icons.calendar_today, color: Colors.grey), // ไอคอนปฏิทิน
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  // Widget for image picker
  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'รูปภาพของคุณ :',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Center(
          child: InkWell(
            onTap: _pickImage,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: _image != null
                  ? Image.file(
                _image!,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              )
                  : Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: Colors.grey),
                ),
                child: const Icon(
                  Icons.add_a_photo,
                  size: 40,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Main build method
  @override
  Widget build(BuildContext context) {
    // Define a color scheme
    final Color primaryColor = Colors.teal;
    final Color accentColor = Colors.tealAccent;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80), // กำหนดความสูงของ AppBar
        child: AppBar(
          automaticallyImplyLeading: false, // เอาปุ่มย้อนกลับออก
          backgroundColor: Colors.transparent, // ทำให้โปร่งใส
          elevation: 0, // เอาเงาออก
          flexibleSpace: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0), // กำหนด padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ปุ่ม "ยืนยัน" ด้านขวา
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _saveInformation,
                    child: _isLoading
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.blue,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text(
                      'ยืนยัน',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // ข้อความ "ข้อมูล" อยู่กลางบรรทัด (ต่ำกว่าปุ่มยืนยัน)
                const Spacer(),
                const Text(
                  'ข้อมูล',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8), // เพิ่มระยะห่างด้านล่าง
              ],
            ),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // ปิดคีย์บอร์ดเมื่อแตะที่อื่น
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ข้อมูลแบบฟอร์ม (ลบ Card ออก)
                _buildInputField(
                  label: 'ชื่อเล่น',
                  hintText: 'กรอกชื่อเล่น',
                  controller: _nicknameController,
                  isRequired: false,
                ),
                _buildInputField(
                  label: 'ชื่อจริง',
                  hintText: 'กรอกชื่อจริง',
                  controller: _firstnameController,
                  isRequired: false,
                ),
                _buildInputField(
                  label: 'นามสกุล',
                  hintText: 'กรอกนามสกุล',
                  controller: _lastnameController,
                  isRequired: false,
                ),
                _buildDatePickerField(
                  label: 'วันเกิด',
                  value: _selectedDate != null
                      ? "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}"
                      : '',
                  onTap: () => _selectDate(context),
                ),
                _buildDropdownField(
                  label: 'ส่วนสูง',
                  value: _selectedHeight,
                  items: List.generate(251, (index) => '${150 + index} ซม.'),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedHeight = newValue;
                      });
                    }
                  },
                ),
                _buildDropdownField(
                  label: 'น้ำหนัก',
                  value: _selectedWeight,
                  items: List.generate(151, (index) => '${50 + index} กก.'),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedWeight = newValue;
                      });
                    }
                  },
                ),
                _buildInputField(
                  label: 'โรคประจำตัว',
                  hintText: 'กรอกโรคประจำตัว (ถ้ามี)',
                  controller: _conditionController,
                ),

                const SizedBox(height: 16),

                // ส่วนของรูปภาพ (ลบ Card ออก)
                _buildImagePicker(),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Colors.white, // ทำให้พื้นหลังเป็นสีขาวเรียบง่าย
    );
  }
}
