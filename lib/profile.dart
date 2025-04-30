import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart'; // For date formatting

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
  final _formKey = GlobalKey<FormState>();
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

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

  /// Helper function to format the date in Thai format.
  String _formatDateThai(DateTime? date) {
    if (date == null) return '';
    // Convert the Gregorian year to Buddhist Era (พ.ศ.)
    final buddhistYear = date.year + 543;
    final day = date.day;
    // Get the full month name in Thai using the 'th_TH' locale.
    final month = DateFormat.MMMM('th_TH').format(date);
    return '$day $month $buddhistYear';
  }

  /// Loads profile data from SharedPreferences.
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

  /// Saves profile data to SharedPreferences.
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
      _isEditing = false; // Exit edit mode
    });
  }

  void _trySaveProfileData() {
    setState(() => _autoValidateMode = AutovalidateMode.always);

    if (!_formKey.currentState!.validate()) {
      return; // ❌ Stop if any required field is invalid
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกวันเกิด')),
      );
      return;
    }

    _saveProfileData(); // ✅ Safe to save now
  }


  /// Selects an image from the gallery.
  Future<void> _pickImage() async {
    final status = await Permission.photos.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ต้องอนุญาตให้เข้าถึงรูปภาพ')),
      );
      return;
    }

    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _imagePath = pickedFile.path;
      });
    }
  }

  /// Uses a custom Thai date picker (via a modal bottom sheet) for selecting the date.
  Future<void> _selectDate(BuildContext context) async {
    DateTime initial = _selectedDate ?? DateTime(2000, 1, 1);
    DateTime? pickedDate = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return ThaiDatePicker(
          initialDate: initial,
          minimumDate: DateTime(1900, 1, 1),
          maximumDate: DateTime.now(),
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Transparent AppBar
        elevation: 0, // Remove shadow
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 8), // Adjust spacing
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white, // White background
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26, // Light shadow
                  blurRadius: 5,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: IconButton(
              onPressed: () {
                Navigator.pop(context); // Go back
              },
              icon: const Icon(Icons.arrow_back, color: Colors.black),
            ),
          ),
        ),
        title: const Text(
          "ข้อมูลส่วนตัว",
          style: TextStyle(color: Colors.black), // Black text
        ),
        centerTitle: true,
        actions: [
          _isEditing
              ? IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: _trySaveProfileData, // Save on tap
                )
              : IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    setState(() {
                      _isEditing = true; // Enter edit mode
                    });
                  },
                ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          autovalidateMode: _autoValidateMode,
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
              _buildEditableField("โรคประจำตัว", _conditionController, isRequired: false),
              const SizedBox(height: 20),
              const Text("รูปโปรไฟล์ :",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Center(
                child: GestureDetector(
                  onTap: _isEditing ? _pickImage : null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _image != null
                        ? Image.file(_image!,
                            width: 120, height: 120, fit: BoxFit.cover)
                        : const Text("ไม่มีรูปภาพ"),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget for an editable text field (active in edit mode).
  Widget _buildEditableField(
      String label,
      TextEditingController controller, {
        bool isRequired = true, // ✅ Add this
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label :',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            enabled: _isEditing,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[200],
              contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              errorStyle: const TextStyle(
                color: Colors.red,
                fontSize: 13,
                height: 1.2,
              ),
            ),
            validator: isRequired
                ? (value) {
              if (_isEditing && (value == null || value.trim().isEmpty)) {
                return 'กรุณากรอก$label';
              }
              return null;
            }
                : null,
          ),
        ],
      ),
    );
  }

  /// Widget for displaying/selecting the date.
  Widget _buildDatePicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "วันเกิด :",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _isEditing ? () => _selectDate(context) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[200], // Light gray background
                borderRadius: BorderRadius.circular(20), // Rounded corners
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedDate != null
                        ? _formatDateThai(_selectedDate)
                        : "เลือกวันเกิด",
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedDate != null ? Colors.black : Colors.grey,
                    ),
                  ),
                  // Show calendar icon only in edit mode.
                  if (_isEditing)
                    const Icon(Icons.calendar_today, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Widget for a dropdown field.
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
              color: Colors.grey[200], // Light gray background
              borderRadius: BorderRadius.circular(20), // Rounded corners
            ),
            child: _isEditing
                ? DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: value,
                      isExpanded: true,
                      onChanged: onChanged,
                      items: items.map((String item) {
                        return DropdownMenuItem<String>(
                          value: item,
                          child:
                              Text(item, style: const TextStyle(fontSize: 16)),
                        );
                      }).toList(),
                    ),
                  )
                : SizedBox(
                    height:
                        50, // Keeps the same height as the dropdown when not editing
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(value, style: const TextStyle(fontSize: 16)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadonlyBox(String value) => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
      child: Text(value));
}

/// Custom ThaiDatePicker widget for selecting dates in Thai format.
class ThaiDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime minimumDate;
  final DateTime maximumDate;

  const ThaiDatePicker({
    Key? key,
    required this.initialDate,
    required this.minimumDate,
    required this.maximumDate,
  }) : super(key: key);

  @override
  _ThaiDatePickerState createState() => _ThaiDatePickerState();
}

class _ThaiDatePickerState extends State<ThaiDatePicker> {
  late int selectedDay;
  late int selectedMonth;
  late int selectedYear;
  late List<int> years;

  @override
  void initState() {
    super.initState();
    selectedDay = widget.initialDate.day;
    selectedMonth = widget.initialDate.month;
    selectedYear = widget.initialDate.year;
    years = List<int>.generate(
      widget.maximumDate.year - widget.minimumDate.year + 1,
      (index) => widget.minimumDate.year + index,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      color: Colors.white,
      child: Column(
        children: [
          // Header with Cancel and Confirm buttons.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ยกเลิก'),
                ),
                TextButton(
                  onPressed: () {
                    DateTime newDate =
                        DateTime(selectedYear, selectedMonth, selectedDay);
                    Navigator.pop(context, newDate);
                  },
                  child: const Text('เลือก'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // The pickers in a row: Day, Month, and Year (with Buddhist Era display).
          Expanded(
            child: Row(
              children: [
                // Day Picker.
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 32,
                    scrollController: FixedExtentScrollController(
                        initialItem: selectedDay - 1),
                    onSelectedItemChanged: (index) {
                      setState(() {
                        selectedDay = index + 1;
                      });
                    },
                    children: List<Widget>.generate(
                      31,
                      (index) => Center(child: Text('${index + 1}')),
                    ),
                  ),
                ),
                // Month Picker showing month names in Thai.
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 32,
                    scrollController: FixedExtentScrollController(
                        initialItem: selectedMonth - 1),
                    onSelectedItemChanged: (index) {
                      setState(() {
                        selectedMonth = index + 1;
                      });
                    },
                    children: List<Widget>.generate(12, (index) {
                      String monthName = DateFormat.MMMM('th_TH')
                          .format(DateTime(2000, index + 1));
                      return Center(child: Text(monthName));
                    }),
                  ),
                ),
                // Year Picker displaying year in Buddhist Era.
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 32,
                    scrollController: FixedExtentScrollController(
                        initialItem: selectedYear - widget.minimumDate.year),
                    onSelectedItemChanged: (index) {
                      setState(() {
                        selectedYear = years[index];
                      });
                    },
                    children: years.map((year) {
                      return Center(child: Text('${year + 543}'));
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
