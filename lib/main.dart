import 'package:flutter/material.dart';
import 'pages/start_triage_page.dart';
import 'pages/record_page.dart';

void main() {
  runApp(TimeSaverStartApp());
}

class TimeSaverStartApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '다수사상자 분류 훈련',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: HomePage(), // ✅ 초기화면
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('다수사상자 분류 훈련')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => StartTriagePage()));
              },
              child: Text('🚑 분류 시작'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => RecordPage()));
              },
              child: Text('📋 기록 보기'),
            ),
          ],
        ),
      ),
    );
  }
}
