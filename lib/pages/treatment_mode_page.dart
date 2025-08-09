import 'dart:math';
import 'package:flutter/material.dart';
import '../pages/record_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TreatmentModePage extends StatefulWidget {
  final List<Map<String, dynamic>> patients;
  final List<Map<String, dynamic>> sessionRecords;
  final Future<void> Function() onSessionSaved;

  const TreatmentModePage({
    Key? key,
    required this.patients,
    required this.sessionRecords,
    required this.onSessionSaved,
  }) : super(key: key);

  @override
  _TreatmentModePageState createState() => _TreatmentModePageState();
}

class _TreatmentModePageState extends State<TreatmentModePage> {
  late List<Map<String, dynamic>> _treatmentList;
  int _treatmentIndex = 0;
  Map<int, List<String>> _treatmentLogs = {};
  List<String> _currentTreatments = List.filled(8, "");
  Map<int, Map<String, dynamic>?> _vitalSignsMap = {};
  Map<int, bool> _vitalCheckedMap = {};

  @override
  void initState() {
    super.initState();
    _treatmentList = List.from(widget.patients);

    // 🔹 START 색상 우선순위: Red > Yellow > Green > Black
    const priority = {'Red': 0, 'Yellow': 1, 'Green': 2, 'Black': 3};
    _treatmentList.sort((a, b) => priority[a['정답']]!.compareTo(priority[b['정답']]!));
  }

  // 🔹 V/S 랜덤 생성 함수
  Map<String, dynamic> generateVitalSigns(Map<String, dynamic> patient) {
    final rand = Random();
    final rr = patient['호흡수'];
    final triage = patient['정답'];

    int sbp, dbp, hr, spo2;

    if (triage == 'Black') {
      sbp = 0;
      dbp = 0;
      hr = 0;
      spo2 = 0;
    } else if (triage == 'Red') {
      sbp = rand.nextInt(21) + 70;  // 70~90
      dbp = rand.nextInt(21) + 40;  // 40~60
      hr = rr > 30 ? rand.nextInt(31) + 120 : rand.nextInt(21) + 110;
      spo2 = rand.nextInt(14) + 75; // 75~88
    } else if (triage == 'Yellow') {
      sbp = rand.nextInt(21) + 90;  // 90~110
      dbp = rand.nextInt(21) + 60;  // 60~80
      hr = rand.nextInt(21) + 100;  // 100~120
      spo2 = rand.nextInt(8) + 88;  // 88~95
    } else {
      sbp = rand.nextInt(21) + 110; // 110~130
      dbp = rand.nextInt(21) + 70;  // 70~90
      hr = rand.nextInt(21) + 80;   // 80~100
      spo2 = rand.nextInt(5) + 95;  // 95~99
    }

    return {
      "SBP": sbp,
      "DBP": dbp,
      "HR": hr,
      "SpO2": spo2,
    };
  }

  void _addTreatment(String action) {
    setState(() {
      if (_currentTreatments.contains(action)) return;

      final idx = _currentTreatments.indexOf("");
      if (idx != -1) {
        _currentTreatments[idx] = action;

        final patientIdx = _treatmentIndex;
        _treatmentLogs.putIfAbsent(patientIdx, () => []);
        _treatmentLogs[patientIdx]!.add(action);
      }
    });
  }

  Future<void> _nextTreatment() async {
    if (_treatmentIndex < _treatmentList.length - 1) {
      setState(() {
        _treatmentIndex++;
        _currentTreatments = List.filled(8, "");
      });
    } else {
      _showTreatmentSummary();

      // 세션 저장
      await widget.onSessionSaved();

      // 초기화 후 기록 페이지로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RecordPage()),
      );
    }
  }

  void _showTreatmentSummary() {
    String summary = "";
    for (int i = 0; i < _treatmentList.length; i++) {
      final p = _treatmentList[i];
      summary += "${i + 1}번 환자 (${p['정답']})\n";
      final logs = _treatmentLogs[i] ?? [];
      for (var t in logs) {
        summary += "  - $t\n";
      }
      summary += "\n";
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("처치 요약"),
        content: SingleChildScrollView(child: Text(summary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("확인"),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCardFull(Map<String, dynamic> patient) {
    final bool checked = _vitalCheckedMap[_treatmentIndex] ?? false;
    final vs = _vitalSignsMap[_treatmentIndex];

    Color getColor(String triage) {
      switch (triage) {
        case 'Red':
          return Colors.red;
        case 'Yellow':
          return Colors.yellow[700]!;
        case 'Green':
          return Colors.green;
        case 'Black':
          return Colors.black;
        default:
          return Colors.grey;
      }
    }

    final triage = patient['정답'] ?? '미분류';
    final triageColor = getColor(triage);
    final triageTextColor = triage == 'Black' ? Colors.white : Colors.black;

    return Card(
      elevation: 4,
      margin: EdgeInsets.all(12),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (patient['image'] != null)
                  Image.asset(
                    patient['image'],
                    width: 180,
                    height: 220,
                    fit: BoxFit.contain,
                  ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text('🗣 ${patient['speech']}',
                                style: TextStyle(fontSize: 16)),
                          ),
                          Container(
                            padding:
                                EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: triageColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              triage,
                              style: TextStyle(
                                color: triageTextColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text('🩸 증상: ${patient['injury']}',
                          style: TextStyle(color: Colors.red[700])),
                      SizedBox(height: 8),
                      Text('🧑 성별: ${patient['gender']}'),
                      Text('🎂 나이: ${patient['age']}세'),
                      Text('🚶 보행: ${patient['canWalk'] ? "가능" : "불가"}'),
                      SizedBox(height: 12),
                      checked && vs != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('🩺 V/S 측정 결과',
                                    style: TextStyle(fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text('BP: ${vs['SBP']}/${vs['DBP']} mmHg'),
                                Text('HR: ${vs['HR']} 회/분'),
                                Text('SpO₂: ${vs['SpO2']} %'),
                              ],
                            )
                          : ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _vitalSignsMap[_treatmentIndex] =
                                      generateVitalSigns(patient);
                                  _vitalCheckedMap[_treatmentIndex] = true;
                                });
                              },
                              child: Text('V/S 측정'),
                            ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Divider(),
            Text("🩺 처치 기록", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: GridView.builder(
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 2.5,
                ),
                itemCount: _currentTreatments.length,
                itemBuilder: (_, idx) {
                  final t = _currentTreatments[idx];
                  return Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                      color: t.isEmpty ? Colors.white : Colors.blue[100],
                    ),
                    child: Text(
                      t.isEmpty ? "□" : t,
                      style: TextStyle(fontSize: 11),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
Widget build(BuildContext context) {
  final p = _treatmentList[_treatmentIndex];

  return Scaffold(
    appBar: AppBar(title: Text('처치반 모드')),
    body: SingleChildScrollView(
      child: Column(
        children: [
          _buildPatientCardFull(p),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(onPressed: () => _addTreatment("지혈"), child: Text("지혈")),
              ElevatedButton(onPressed: () => _addTreatment("O₂"), child: Text("O₂")),
              ElevatedButton(onPressed: () => _addTreatment("AED"), child: Text("AED")),
              ElevatedButton(onPressed: () => _addTreatment("IV"), child: Text("IV")),
              ElevatedButton(onPressed: () => _addTreatment("상처 드레싱"), child: Text("상처 드레싱")),
              ElevatedButton(onPressed: () => _addTreatment("부목"), child: Text("부목")),
              ElevatedButton(onPressed: () => _addTreatment("경추보호대"), child: Text("경추보호대")),
              ElevatedButton(onPressed: () => _addTreatment("전문기도술"), child: Text("전문기도술")),
              ElevatedButton(onPressed: () => _addTreatment("에피네프린"), child: Text("에피네프린")),
              ElevatedButton(onPressed: () => _addTreatment("수액"), child: Text("수액")),
            ],
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _nextTreatment,
            child: Text(
              _treatmentIndex < _treatmentList.length - 1
                  ? '처치 완료 → 다음 환자'
                  : '모든 환자 처치 완료',
            ),
          ),
        ],
      ),
    ),
  );
}
}