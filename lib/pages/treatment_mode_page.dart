// lib/pages/treatment_mode_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../pages/record_page.dart';

class TreatmentModePage extends StatefulWidget {
  final List<Map<String, dynamic>> patients;
  final List<Map<String, dynamic>> sessionRecords;

  // ✅ nullable 로 바꿔서 없으면 호출 안 함
  final Future<void> Function()? onSessionSaved;

  const TreatmentModePage({
    Key? key,
    required this.patients,
    required this.sessionRecords,
    this.onSessionSaved,
  }) : super(key: key);

  @override
  _TreatmentModePageState createState() => _TreatmentModePageState();
}

class _TreatmentModePageState extends State<TreatmentModePage> {
  late List<Map<String, dynamic>> _treatmentList;
  int _treatmentIndex = 0;
  final Map<int, List<String>> _treatmentLogs = {};
  List<String> _currentTreatments = List.filled(8, "");
  final Map<int, Map<String, dynamic>?> _vitalSignsMap = {};
  final Map<int, bool> _vitalCheckedMap = {};

  bool _finishing = false; // ✅ 종료 중 중복 방지

  @override
  void initState() {
    super.initState();
    _treatmentList = List.from(widget.patients);

    // ✅ 한글 라벨 기준 우선순위: 긴급 > 응급 > 비응급 > 사망
    const priorityKo = {'긴급': 0, '응급': 1, '비응급': 2, '사망': 3};
    _treatmentList.sort((a, b) {
      final ak = (a['정답'] ?? '').toString();
      final bk = (b['정답'] ?? '').toString();
      final ai = priorityKo[ak] ?? 99;
      final bi = priorityKo[bk] ?? 99;
      return ai.compareTo(bi);
    });
  }

  // 🔹 V/S 랜덤 생성 — 한글 라벨 기반
  Map<String, dynamic> generateVitalSigns(Map<String, dynamic> patient) {
    final rand = Random();
    final rr = (patient['호흡수'] ?? 20) as int;
    final triage = (patient['정답'] ?? '비응급') as String;

    int sbp, dbp, hr, spo2;

    if (triage == '사망') {
      sbp = 0; dbp = 0; hr = 0; spo2 = 0;
    } else if (triage == '긴급') {
      sbp = rand.nextInt(21) + 70;   // 70~90
      dbp = rand.nextInt(21) + 40;   // 40~60
      hr  = rr > 30 ? rand.nextInt(31) + 120 : rand.nextInt(21) + 110;
      spo2 = rand.nextInt(14) + 75;  // 75~88
    } else if (triage == '응급') {
      sbp = rand.nextInt(21) + 90;   // 90~110
      dbp = rand.nextInt(21) + 60;   // 60~80
      hr  = rand.nextInt(21) + 100;  // 100~120
      spo2 = rand.nextInt(8) + 88;   // 88~95
    } else { // 비응급
      sbp = rand.nextInt(21) + 110;  // 110~130
      dbp = rand.nextInt(21) + 70;   // 70~90
      hr  = rand.nextInt(21) + 80;   // 80~100
      spo2 = rand.nextInt(5) + 95;   // 95~99
    }

    return {"SBP": sbp, "DBP": dbp, "HR": hr, "SpO2": spo2};
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
      return;
    }

    if (_finishing) return;
    _finishing = true;

    // ✅ 요약 다이얼로그 닫힌 뒤 진행
    await _showTreatmentSummary();

    // ✅ 세션 저장 콜백이 있으면 한 번만 호출
    if (widget.onSessionSaved != null) {
      await widget.onSessionSaved!();
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RecordPage()),
    );
  }

  Future<void> _showTreatmentSummary() async {
    final buf = StringBuffer();
    for (int i = 0; i < _treatmentList.length; i++) {
      final p = _treatmentList[i];
      buf.writeln('${i + 1}번 환자 (${p['정답'] ?? '미정'})');
      final logs = _treatmentLogs[i] ?? const <String>[];
      for (final t in logs) {
        buf.writeln('  - $t');
      }
      buf.writeln();
    }

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('처치 요약'),
        content: SingleChildScrollView(child: Text(buf.toString())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
        ],
      ),
    );
  }

  Widget _buildPatientCardFull(Map<String, dynamic> patient) {
    final bool checked = _vitalCheckedMap[_treatmentIndex] ?? false;
    final vs = _vitalSignsMap[_treatmentIndex];

    Color getColorKo(String triageKo) {
      switch (triageKo) {
        case '긴급': return Colors.red;
        case '응급': return Colors.yellow[700]!;
        case '비응급': return Colors.green;
        case '사망': return Colors.black;
        default: return Colors.grey;
      }
    }

    final triageKo = (patient['정답'] ?? '미분류') as String;
    final triageColor = getColorKo(triageKo);
    final triageTextColor = triageKo == '사망' ? Colors.white : Colors.black;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text('🗣 ${patient['speech']}', style: const TextStyle(fontSize: 16)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: triageColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              triageKo,
                              style: TextStyle(
                                color: triageTextColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text('🩸 증상: ${patient['injury']}', style: TextStyle(color: Colors.red[700])),
                      const SizedBox(height: 8),
                      Text('🧑 성별: ${patient['gender']}'),
                      Text('🎂 나이: ${patient['age']}세'),
                      Text('🚶 보행: ${patient['canWalk'] == true ? "가능" : "불가"}'),
                      const SizedBox(height: 12),
                      checked && vs != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('🩺 V/S 측정 결과', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('BP: ${vs['SBP']}/${vs['DBP']} mmHg'),
                                Text('HR: ${vs['HR']} 회/분'),
                                Text('SpO₂: ${vs['SpO2']} %'),
                              ],
                            )
                          : ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _vitalSignsMap[_treatmentIndex] = generateVitalSigns(patient);
                                  _vitalCheckedMap[_treatmentIndex] = true;
                                });
                              },
                              child: const Text('V/S 측정'),
                            ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            const Text('🩺 처치 기록', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                    child: Text(t.isEmpty ? '□' : t, style: const TextStyle(fontSize: 11)),
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
      appBar: AppBar(title: const Text('처치반 모드')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildPatientCardFull(p),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(onPressed: () => _addTreatment('지혈'), child: const Text('지혈')),
                ElevatedButton(onPressed: () => _addTreatment('O₂'), child: const Text('O₂')),
                ElevatedButton(onPressed: () => _addTreatment('AED'), child: const Text('AED')),
                ElevatedButton(onPressed: () => _addTreatment('IV'), child: const Text('IV')),
                ElevatedButton(onPressed: () => _addTreatment('상처 드레싱'), child: const Text('상처 드레싱')),
                ElevatedButton(onPressed: () => _addTreatment('부목'), child: const Text('부목')),
                ElevatedButton(onPressed: () => _addTreatment('경추보호대'), child: const Text('경추보호대')),
                ElevatedButton(onPressed: () => _addTreatment('전문기도술'), child: const Text('전문기도술')),
                ElevatedButton(onPressed: () => _addTreatment('에피네프린'), child: const Text('에피네프린')),
                ElevatedButton(onPressed: () => _addTreatment('수액'), child: const Text('수액')),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _finishing ? null : _nextTreatment,
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
