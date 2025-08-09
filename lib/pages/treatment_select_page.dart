// lib/pages/treatment_select_page.dart
import 'package:flutter/material.dart';
import 'treatment_mode_page.dart';
import '../pages/record_page.dart';

class TreatmentSelectPage extends StatelessWidget {
  final List<Map<String, dynamic>> classifiedPatients;
  final List<Map<String, dynamic>> sessionRecords;

  // ✅ nullable 로 변경
  final Future<void> Function()? onSessionSaved;

  const TreatmentSelectPage({
    super.key,
    required this.classifiedPatients,
    required this.sessionRecords,
    this.onSessionSaved, // ✅ required 제거
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
                      // ✅ 넘길 때도 nullable
                      onSessionSaved: onSessionSaved ?? (() async {}),
                    ),
                  ),
                );
              },
              child: const Text('처치반 모드 시작'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                // ✅ 호출 가드
                if (onSessionSaved != null) {
                  await onSessionSaved!();
                }
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const RecordPage()),
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
