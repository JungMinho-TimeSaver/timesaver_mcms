import 'package:flutter/material.dart';
import 'treatment_mode_page.dart';
import '../pages/record_page.dart';

class TreatmentSelectPage extends StatelessWidget {
  final List<Map<String, dynamic>> classifiedPatients;
  final List<Map<String, dynamic>> sessionRecords;
  final Future<void> Function() onSessionSaved;

  const TreatmentSelectPage({
    super.key,
    required this.classifiedPatients,
    required this.sessionRecords,
    required this.onSessionSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('처치반 모드 선택')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TreatmentModePage(
                      patients: classifiedPatients,
                      sessionRecords: sessionRecords,
                      onSessionSaved: onSessionSaved,
                    ),
                  ),
                );
              },
              child: const Text('처치반 모드 시작'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await onSessionSaved(); // 세션 저장
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => RecordPage()),
                  (route) => false,
                );
              },
              child: const Text('처치반 모드 건너뛰기'),
            ),
          ],
        ),
      ),
    );
  }
}
