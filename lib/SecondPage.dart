// SecondPage.dart
import 'package:flutter/material.dart';
import 'dart:math';

class SecondPage extends StatelessWidget {

  final List<String> quotes = [
    "The best way to predict the future is to create it.",
    "Success is not the key to happiness. Happiness is the key to success.",
    "Don’t watch the clock; do what it does. Keep going.",
    "The only way to do great work is to love what you do.",
    "Believe you can and you’re halfway there.",
  ];

  String getRandomQuote() {
    final random = Random();
    return quotes[random.nextInt(quotes.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Second Page'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              getRandomQuote(),
              style: TextStyle(fontSize: 20, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}