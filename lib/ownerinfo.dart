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
      final pickedFile =
      await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        debugPrint("Image selected: ${pickedFile.path}");
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
      // If form is not valid, do not proceed
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nickname', _nicknameController.text.trim());
      await prefs.setString('firstname', _firstnameController.text.trim());
      await prefs.setString('lastname', _lastnameController.text.trim());
      await prefs.setString(
          'birthdate', _selectedDate?.toIso8601String() ?? '');
      await prefs.setString('height', _selectedHeight);
      await prefs.setString('weight', _selectedWeight);
      await prefs.setString('condition', _conditionController.text.trim());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ข้อมูลถูกบันทึกเรียบร้อยแล้ว!')),
      );

      // Navigate to SecondPage after a short delay to allow snackbar to show
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

  // Reusable widget for input fields with validation
  Widget _buildInputField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label${isRequired ? ' *' : ''}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hintText,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8.0)),
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding:
              const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
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
        ],
      ),
    );
  }

  // Reusable widget for dropdown fields
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
          DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8.0)),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            onChanged: onChanged,
            items: items
                .map<DropdownMenuItem<String>>(
                  (String item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              ),
            )
                .toList(),
          ),
        ],
      ),
    );
  }

  // Widget for date picker
  Widget _buildDatePicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'วันเกิด :',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _selectDate(context),
            child: Container(
              padding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8.0),
                color: Colors.grey[100],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedDate != null
                        ? "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}"
                        : 'เลือกวันเกิด',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Icon(Icons.calendar_today, color: Colors.grey),
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
          'รูปภาพโปรไฟล์ :',
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
      appBar: AppBar(
        title: const Text(
          'ข้อมูลผู้ใช้',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveInformation,
              icon: const Icon(Icons.check),
              label: _isLoading
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Text(
                'ยืนยัน',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white, backgroundColor: primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
        ],
        backgroundColor: primaryColor,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // User Information Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        _buildDatePicker(),
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Image Picker Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildImagePicker(),
                  ),
                ),
                const SizedBox(height: 24),
                // Submit Button (alternative for accessibility)
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveInformation,
                  child: _isLoading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'ยืนยันข้อมูล',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white, backgroundColor: primaryColor,
                    minimumSize: const Size.fromHeight(50), // Full width
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Colors.grey[50],
    );
  }
}
