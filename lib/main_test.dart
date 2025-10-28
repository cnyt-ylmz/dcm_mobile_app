import 'package:flutter/material.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DCM Mobile Test',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('DCM Mobile Test'),
        ),
        body: const Center(
          child: Text(
            'DCM Mobile Test Uygulaması Çalışıyor!',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }
}
