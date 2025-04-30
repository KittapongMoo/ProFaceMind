import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'setmap.dart'; // แผนที่
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
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  bool get _isFormValid {
    return _formKey.currentState?.validate() == true &&
        _selectedDate != null &&
        _image != null;
  }

  @override
  void initState() {
    super.initState();
    // 🗑️🔄️ Clear ข้อมูลผู้ใช้ให้เหมือนตอนเริ่มต้น
    // SharedPreferences.getInstance().then((prefs) => prefs.clear());
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

  String _formatDateThai(DateTime? date) {
    if (date == null) return '';
    // Convert year to Buddhist Era year (พ.ศ.)
    final buddhistYear = date.year + 543;
    final day = date.day;
    // Get the full month name in Thai using the 'th_TH' locale
    final month = DateFormat.MMMM('th_TH').format(date);
    return '$day $month $buddhistYear';
  }

  Future<void> _selectThaiDate(BuildContext context) async {
    // Use a temporary value for initial date if _selectedDate is null.
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


  // Method to save information to SharedPreferences
  Future<void> _saveInformation() async {
    setState(() {
      _autoValidateMode = AutovalidateMode.always; // Enable validation only now
    });

    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกวันเกิด')),
      );
      return;
    }

    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกรูปภาพโปรไฟล์')),
      );
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
      await prefs.setString('birthdate', _selectedDate!.toIso8601String());
      await prefs.setString('height', _selectedHeight);
      await prefs.setString('weight', _selectedWeight);
      await prefs.setString('condition', _conditionController.text.trim());
      await prefs.setString('imagePath', _image!.path);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ข้อมูลถูกบันทึกเรียบร้อยแล้ว!')),
      );

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Setmap()),
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

      _autoValidateMode = AutovalidateMode.disabled; // ✅ Add this line here too
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
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
              filled: true,
              fillColor: Colors.grey[200],
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              errorStyle: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.red,
              ),
            ),
            validator: isRequired
                ? (value) {
              if (value == null || value.trim().isEmpty) {
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
      child: FormField<DateTime>(
        validator: (_) {
          if (_autoValidateMode == AutovalidateMode.always && _selectedDate == null) {
            return 'กรุณาเลือก$label';
          }
          return null;
        },
        builder: (FormFieldState<DateTime> field) {
          return Column(
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
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        value.isNotEmpty ? value : 'เลือก $label',
                        style: TextStyle(
                          fontSize: 16,
                          color: value.isNotEmpty ? Colors.black : Colors.grey,
                        ),
                      ),
                      const Icon(Icons.calendar_today, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              if (field.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                  child: Text(
                    field.errorText!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }


  // Widget for image picker
  Widget _buildImagePicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: FormField<File>(
        validator: (_) {
          if (_autoValidateMode == AutovalidateMode.always && _image == null) {
            return 'กรุณาเลือกรูปภาพโปรไฟล์';
          }
          return null;
        },
        builder: (FormFieldState<File> field) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              if (field.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    field.errorText!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _resetInformation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('nickname');
    await prefs.remove('firstname');
    await prefs.remove('lastname');
    await prefs.remove('birthdate');
    await prefs.remove('height');
    await prefs.remove('weight');
    await prefs.remove('condition');
    await prefs.remove('imagePath');

    setState(() {
      _nicknameController.clear();
      _firstnameController.clear();
      _lastnameController.clear();
      _conditionController.clear();
      _selectedDate = null;
      _selectedHeight = "150 ซม.";
      _selectedWeight = "50 กก.";
      _image = null;
      _imagePath = null;
      _autoValidateMode = AutovalidateMode.disabled; // 👈 Add this line
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ข้อมูลทั้งหมดถูกรีเซตแล้ว')),
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
            autovalidateMode: _autoValidateMode,
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ข้อมูลแบบฟอร์ม (ลบ Card ออก)
                _buildInputField(
                  label: 'ชื่อเล่น',
                  hintText: 'กรอกชื่อเล่น',
                  controller: _nicknameController,
                  isRequired: true,
                ),
                _buildInputField(
                  label: 'ชื่อจริง',
                  hintText: 'กรอกชื่อจริง',
                  controller: _firstnameController,
                  isRequired: true,
                ),
                _buildInputField(
                  label: 'นามสกุล',
                  hintText: 'กรอกนามสกุล',
                  controller: _lastnameController,
                  isRequired: true,
                ),
                _buildDatePickerField(
                  label: 'วันเกิด',
                  value: _selectedDate != null ? _formatDateThai(_selectedDate) : '',
                  onTap: () => _selectThaiDate(context),
                ),
                _buildDropdownField(
                  label: 'ส่วนสูง',
                  value: _selectedHeight,
                  items: List.generate(251, (index) => '${0 + index} ซม.'),
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
                  items: List.generate(151, (index) => '${0 + index} กก.'),
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

                // สำหรับรีเซตข้อมูลวันจริงเอาออกด้วย
                // TextButton.icon(
                //   onPressed: _resetInformation,
                //   icon: const Icon(Icons.restart_alt, color: Colors.red),
                //   label: const Text(
                //     'รีเซตข้อมูล (Dev)',
                //     style: TextStyle(color: Colors.red),
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Colors.white, // ทำให้พื้นหลังเป็นสีขาวเรียบง่าย
    );
  }
}

class ThaiDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime minimumDate;
  final DateTime maximumDate;
  final void Function(int year, int month, int day)? onDateChanged;

  const ThaiDatePicker({
    Key? key,
    required this.initialDate,
    required this.minimumDate,
    required this.maximumDate,
    this.onDateChanged,
  }) : super(key: key);

  @override
  _ThaiDatePickerState createState() => _ThaiDatePickerState();
}

class _ThaiDatePickerState extends State<ThaiDatePicker> {
  late int selectedDay, selectedMonth, selectedYear;
  late List<int> years;

  @override
  void initState() {
    super.initState();
    selectedDay   = widget.initialDate.day;
    selectedMonth = widget.initialDate.month;
    selectedYear  = widget.initialDate.year;

    // build the full list of valid years
    years = List<int>.generate(
      widget.maximumDate.year - widget.minimumDate.year + 1,
          (i) => widget.minimumDate.year + i,
    );
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.maximumDate;
    final min = widget.minimumDate;

    // clamp the year
    if (selectedYear < min.year) selectedYear = min.year;
    if (selectedYear > max.year) selectedYear = max.year;

    // determine valid months for this year
    final isMaxYear = selectedYear == max.year;
    final monthCount = isMaxYear ? max.month : 12;
    final months = List<int>.generate(monthCount, (i) => i + 1);

    // clamp month
    if (selectedMonth < 1) selectedMonth = 1;
    if (selectedMonth > monthCount) selectedMonth = monthCount;

    // determine days in this selected month/year
    final daysInMonth = DateUtils.getDaysInMonth(selectedYear, selectedMonth);
    // if this is the current month of the max year, cap at max.day
    final isMaxMonth = isMaxYear && selectedMonth == max.month;
    final dayCount = isMaxMonth ? max.day : daysInMonth;
    final days = List<int>.generate(dayCount, (i) => i + 1);

    // clamp day
    if (selectedDay < 1) selectedDay = 1;
    if (selectedDay > dayCount) selectedDay = dayCount;

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // ─── Day Picker ─────────────────
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 32,
                  scrollController:
                  FixedExtentScrollController(initialItem: selectedDay - 1),
                  onSelectedItemChanged: (i) {
                    setState(() => selectedDay = days[i]);
                    widget.onDateChanged
                        ?.call(selectedYear, selectedMonth, selectedDay);
                  },
                  children: days
                      .map((d) => Center(child: Text('$d')))
                      .toList(),
                ),
              ),

              // ─── Month Picker ────────────────
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 32,
                  scrollController: FixedExtentScrollController(
                      initialItem: months.indexOf(selectedMonth)),
                  onSelectedItemChanged: (i) {
                    setState(() => selectedMonth = months[i]);
                    widget.onDateChanged
                        ?.call(selectedYear, selectedMonth, selectedDay);
                  },
                  children: months.map((m) {
                    final mName = DateFormat.MMMM('th_TH')
                        .format(DateTime(2000, m));
                    return Center(child: Text(mName));
                  }).toList(),
                ),
              ),

              // ─── Year Picker ─────────────────
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 32,
                  scrollController: FixedExtentScrollController(
                    initialItem: years.indexOf(selectedYear),
                  ),
                  onSelectedItemChanged: (i) {
                    setState(() => selectedYear = years[i]);
                    widget.onDateChanged
                        ?.call(selectedYear, selectedMonth, selectedDay);
                  },
                  children: years
                      .map((y) => Center(child: Text('${y + 543}')))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

