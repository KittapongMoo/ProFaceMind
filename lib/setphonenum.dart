import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'secondpage.dart';

class SetPhoneNumber extends StatefulWidget {
  const SetPhoneNumber({Key? key}) : super(key: key);

  @override
  _SetPhoneNumberState createState() => _SetPhoneNumberState();
}

class _SetPhoneNumberState extends State<SetPhoneNumber> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  /// **📌 โหลดข้อมูลที่เคยบันทึกไว้**
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('emergency_name') ?? '';
      _relationController.text = prefs.getString('emergency_relation') ?? '';
      _phoneController.text = prefs.getString('emergency_phone') ?? '';
    });
  }

  /// **📌 บันทึกข้อมูลเบอร์ฉุกเฉินลง `SharedPreferences`**
  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('emergency_name', _nameController.text.trim());
      await prefs.setString('emergency_relation', _relationController.text.trim());
      await prefs.setString('emergency_phone', _phoneController.text.trim());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ข้อมูลถูกบันทึกเรียบร้อยแล้ว!')),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SecondPage()),
      );
    } catch (e) {
      debugPrint("Error saving emergency contact: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดขณะบันทึกข้อมูล: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าเบอร์โทรฉุกเฉิน'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ตั้งค่าเบอร์โทรศัพท์ฉุกเฉินของคุณ',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'กรุณาใส่เบอร์โทรศัพท์บุคคลใกล้ชิดของคุณ ที่สามารถติดต่อได้หากเกิดเหตุฉุกเฉิน',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 20),

              _buildInputField(
                label: 'ชื่อ',
                hintText: 'กรุณาระบุชื่อ...',
                controller: _nameController,
                keyboardType: TextInputType.name,
                isRequired: true,
              ),

              _buildInputField(
                label: 'ความสัมพันธ์',
                hintText: 'กรุณาระบุความสัมพันธ์...',
                controller: _relationController,
                keyboardType: TextInputType.text,
                isRequired: true,
              ),

              _buildInputField(
                label: 'เบอร์โทร',
                hintText: 'กรอกเบอร์โทร...',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                isRequired: true,
              ),

              const SizedBox(height: 30),

              Center(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
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
                    'บันทึกข้อมูล',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// **📌 Widget ฟอร์มกรอกข้อมูล**
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
              contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
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
}
