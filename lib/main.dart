import 'package:flutter/material.dart';
// import 'FirstPage.dart';
import 'Ownerinfo.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      debugShowCheckedModeBanner: false,
      home: const PersonalInfoPage(),
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('th', 'TH'), // Ensure Thai locale is supported
      ],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

class PersonalInfoPage extends StatelessWidget {
  const PersonalInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3E7F1), // Light blue background
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Profile Icon with background
          Container(
            width: 180,
            height: 180,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person,
              size: 120,
              color: Colors.blue[200],
            ),
          ),
          const SizedBox(height: 20),
          // Page indicator dots
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
          const SizedBox(height: 20),
          // Title text
          const Text(
            "ข้อมูลส่วนตัว",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          // Description text
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              "กรุณากรอกข้อมูลส่วนตัวของผู้ใช้เพื่อเป็นข้อมูลในการระบุตัวตนของเจ้าของเครื่อง",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          ),
          const Spacer(),
          // Button
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Ownerinfo()), // Navigate to FirstPage
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007BFF), // Bright blue
              padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 15),
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
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
