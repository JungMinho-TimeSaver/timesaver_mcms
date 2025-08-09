// lib/pages/start_triage_page.dart
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pages/record_page.dart';
import '../pages/treatment_mode_page.dart';
import 'treatment_select_page.dart';

class StartTriagePage extends StatefulWidget {
  @override
  State<StartTriagePage> createState() => _StartTriagePageState();
}

class _StartTriagePageState extends State<StartTriagePage> {
  // 한/영 라벨 매핑
  static const Map<String, String> _enToKo = {
    'Red': '긴급',
    'Yellow': '응급',
    'Green': '비응급',
    'Black': '사망',
  };
  static const Map<String, String> _koToEn = {
    '긴급': 'Red',
    '응급': 'Yellow',
    '비응급': 'Green',
    '사망': 'Black',
  };

  Color _colorFor(String ko) {
    switch (ko) {
      case '긴급': return Colors.red;
      case '응급': return Colors.yellow;
      case '비응급': return Colors.green;
      case '사망': return Colors.black;
      default: return Colors.grey;
    }
  }

  final Random _random = Random();

  // 상태
  List<Map<String, dynamic>> _patients = [];
  Map<String, dynamic> _currentPatient = {};
  String? _selectedAnswer;
  String? _feedback;
  bool _answered = false;

  DateTime? _patientStartTime;     // 환자 시작 시각
  DateTime? _sessionStartTime;     // 세션 시작 시각

  final List<Map<String, dynamic>> _sessionRecords = [];     // [{patient,time(sec),correct}]
  final List<Map<String, dynamic>> _classifiedPatients = [];

  int _correctCount = 0;
  int _patientCount = 0;
  final int _maxPatients = 5;

  // 저장 가드(중복 방지)
  bool _savingSession = false;
  bool _sessionSaved = false;

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now(); // 세션 시작 시각 고정
    _loadPatients();
  }

  // ---------------- Firestore 저장(세션 + 누적 집계) ----------------
  Future<void> _saveSessionToFirestore(
    Map<String, dynamic> sessionData, {
    required int gainedScore,
    required int patientsInSession,
    required int sumTimeMsInSession,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('profile_name') ?? 'unknown';
      final code = prefs.getString('profile_code') ?? '0000';
      final profileId = '${name.trim().toLowerCase()}_${code.trim()}';

      final fs = FirebaseFirestore.instance;
      final userRef = fs.collection('users').doc(profileId);

      // 1) 세션 저장
      await userRef.collection('sessions').add({
        ...sessionData, // sessionStartMs, endedAtMs, records, etc.
        'profile': {'name': name, 'code': code},
        'savedAt': FieldValue.serverTimestamp(),
      });

      // 2) 누적 집계 갱신
      await fs.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        final prev = snap.data() as Map<String, dynamic>?;

        final prevScore      = (prev?['totalScore'] ?? 0) as int;
        final prevCount      = (prev?['count'] ?? 0) as int;      // 세션 수
        final prevPatientSum = (prev?['patientSum'] ?? 0) as int; // 누적 환자 수
        final prevTimeSumMs  = (prev?['timeSumMs'] ?? 0) as int;  // 누적 시간 합

        final newScore      = prevScore + gainedScore;
        final newCount      = prevCount + 1;
        final newPatientSum = prevPatientSum + patientsInSession;
        final newTimeSumMs  = prevTimeSumMs + sumTimeMsInSession;
        final newAvgTimeMs  = newPatientSum > 0 ? (newTimeSumMs / newPatientSum).round() : 0;

        tx.set(userRef, {
          'name': name,
          'code': code,
          'totalScore': newScore,
          'count': newCount,
          'patientSum': newPatientSum,
          'timeSumMs': newTimeSumMs,
          'avgTimeMs': newAvgTimeMs,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint('Firestore 저장/집계 실패: $e');
    }
  }

  // ---------------- 세션 저장(로컬 + Firestore) ----------------
 Future<void> _saveSessionToPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getStringList('session_records') ?? <String>[];

  final total = _sessionRecords.length; // 환자 수
if (total == 0) return;               // 빈 세션은 저장 안 함

// ✔ 정답 수 = myAnswer == correctAnswer 개수
final correctCount = _sessionRecords.where((r) =>
    r['myAnswer'] != null &&
    r['myAnswer'] == r['correctAnswer']).length;

// time 이 이제 double(초) 이므로 double 로 합산
final sumSec = _sessionRecords.fold<double>(0.0, (a, r) {
  final t = r['time'];
  if (t is num) return a + t.toDouble();
  return a;
});

// Firestore/관리자 페이지 호환을 위해 avgTimeMs 는 계속 ms(int)로 저장
final sumMs = (sumSec * 1000).round();           // 전체 ms (int)
final avgTimeMs = (sumMs / total).round();       // 1인당 평균 ms (int)

  final startedMs = _sessionStartTime?.millisecondsSinceEpoch
      ?? DateTime.now().millisecondsSinceEpoch;
  final endedMs   = DateTime.now().millisecondsSinceEpoch;

  // 환자 카드 복원용 스냅샷(필요 필드만)
  final patientsSnapshot = _classifiedPatients.map((p0) {
    final p = Map<String, dynamic>.from(p0);
    return {
      'image': p['image'] ?? '',
      'speech': p['speech'],
      'injury': p['injury'],
      'gender': p['gender'],
      'age': p['age'],
      'canWalk': p['canWalk'] ?? false,
      '호흡수': p['호흡수'],
      'refillTime': p['refillTime'],
      'hasPulse': p['hasPulse'],
      'mentalStatus': p['mentalStatus'],
      'followsCommand': p['followsCommand'],
      '기도결과': p['기도결과'],
      '정답': p['정답'],           // KO
      'triage_en': p['triage_en'], // EN
    };
  }).toList();

  // 세션 데이터(요약 + 기록 + 카드)
  final sessionData = {
    'sessionStartMs': startedMs,
    'endedAtMs': endedMs,
    'total': total,
    'correct': correctCount,
    'accuracy': correctCount / total,   // 0~1
    'avgTimeMs': avgTimeMs,
    'records': _sessionRecords,         // [{patient,time,myAnswer,correctAnswer}]
    'patients': patientsSnapshot,
  };

  // 로컬 백업
  existing.add(jsonEncode(sessionData));
  await prefs.setStringList('session_records', existing);

  // Firestore 저장 + 누적 집계
  await _saveSessionToFirestore(
    sessionData,
    gainedScore: correctCount,
    patientsInSession: total,
    sumTimeMsInSession: sumMs,
  );

  // 다음 세션 대비 정리
  _sessionRecords.clear();
  _classifiedPatients.clear();
  _sessionStartTime = null;
}



  // 1회 저장 보장(버튼 연타 방지)
  Future<void> _saveSessionOnce() async {
    if (_savingSession || _sessionSaved) return;
    _savingSession = true;
    try {
      await _saveSessionToPrefs();
      _sessionSaved = true;
    } finally {
      _savingSession = false;
    }
  }

  // ---------------- 해설 생성 ----------------
  // ===== 해설 생성(정상 범위 포함, 성인 기준) =====
// ===== 해설 생성(벗어난 기준만 표시) =====
String generateExplanation(Map<String, dynamic> p) {
  final int rr = (p['호흡수'] is num) ? (p['호흡수'] as num).toInt() : 0;
  final double crt = (p['refillTime'] is num)
      ? (p['refillTime'] as num).toDouble()
      : double.tryParse('${p['refillTime'] ?? ''}') ?? 0.0;
  final bool pulse = p['hasPulse'] == true;
  final String mental = (p['mentalStatus'] ?? '').toString();
  final bool follow = p['followsCommand'] == true;

  // 정상 기준(성인 START)
  const String normR  = '10~30회/분';
  const String normCR = '≤2.0초';
  const String normP  = '말초맥박 촉지';
  const String normM  = '지시수행 가능, U 아님';

  final out = <String>[];

  // R
  if (rr == 0) {
    final airway = p['기도결과'];
    if (airway == '호흡 확인됨') {
      out.add('무호흡 → 기도개방 후 호흡 확인됨 (정상 $normR)');
    } else {
      out.add('무호흡 (정상 $normR)');
    }
  } else {
    if (rr < 10) out.add('호흡수 $rr회/분 (정상 $normR)');
    if (rr > 30) out.add('호흡수 $rr회/분 (정상 $normR)');
  }

  // P
  if (crt > 2.0) out.add('모세혈관충혈 ${crt.toStringAsFixed(1)}초 (정상 $normCR)');
  if (!pulse) out.add('말초맥박 촉지 안됨 (정상 $normP)');

  // M
  if (mental == 'U') out.add('의식 U');
  if (!follow) out.add('지시수행 불가 (정상 $normM)');

  if (out.isEmpty) {
    // 벗어난 항목이 하나도 없으면 간단히 정상 처리만 표기
    return '모든 항목 정상 범위 내';
  }
  return out.join('\n');
}


  // ---------------- 환자 로드 ----------------
  Future<void> _loadPatients() async {
    final jsonString =
        await rootBundle.loadString('assets/patients/generated_patients.json');
    final List<dynamic> jsonList = json.decode(jsonString);
    setState(() {
      _patients = jsonList.cast<Map<String, dynamic>>();
    });
    _loadNextPatient();
  }

  void _loadNextPatient() {
    if (_patients.isEmpty) return;

    final patient =
        Map<String, dynamic>.from(_patients[_random.nextInt(_patients.length)]);

    // 랜덤 값
    patient['호흡수'] =
        _random.nextInt(patient['breathingRange'][1] - patient['breathingRange'][0] + 1) +
        patient['breathingRange'][0];
    patient['age'] =
        _random.nextInt(patient['ageRange'][1] - patient['ageRange'][0] + 1) +
        patient['ageRange'][0];
    patient['refillTime'] = (_random.nextDouble() *
                (patient['refillTimeRange'][1] - patient['refillTimeRange'][0]) +
            patient['refillTimeRange'][0])
        .toStringAsFixed(1);
    patient['canWalk'] = false;

    // START 분류
    String ko;
    if (patient['호흡수'] == 0 && patient['needAirway']) {
      ko = '미정';
    } else if (patient['호흡수'] > 30 ||
        patient['호흡수'] < 10 ||
        double.parse(patient['refillTime']) > 2.0 ||
        patient['hasPulse'] == false) {
      ko = '긴급';
    } else if (patient['mentalStatus'] == 'U') {
      ko = '긴급';
    } else if (!patient['followsCommand']) {
      ko = '응급';
    } else {
      ko = patient['canWalk'] ? '비응급' : '응급';
    }

    setState(() {
      _selectedAnswer = null;
      _feedback = null;
      _answered = false;

      _currentPatient = patient;
      _currentPatient['기도결과'] = null;

      _currentPatient['정답'] = ko;
      _currentPatient['triage_en'] = _koToEn[ko];

      _patientStartTime = DateTime.now();
    });
  }

  // ---------------- 기도 확인 ----------------
  void _checkAirway() {
    final result = _random.nextBool() ? '호흡 확인됨' : '호흡 없음';
    setState(() {
      _currentPatient['기도결과'] = result;
      if (_currentPatient['호흡수'] == 0 && result == '호흡 확인됨') {
        _currentPatient['정답'] = '긴급';
        _currentPatient['triage_en'] = 'Red';
      } else if (_currentPatient['호흡수'] == 0 && result == '호흡 없음') {
        _currentPatient['정답'] = '사망';
        _currentPatient['triage_en'] = 'Black';
      }
    });
  }

  // ---------------- 정답 체크 ----------------
  void _checkAnswer(String selectedKo) {
  // 기도 전에는 선택 불가
  if (_answered ||
      (_currentPatient['호흡수'] == 0 &&
          _currentPatient['needAirway'] == true &&
          _currentPatient['기도결과'] == null)) return;

  setState(() {
    _selectedAnswer = selectedKo;

    final correctKo = _currentPatient['정답'] as String;
    final isCorrect = selectedKo == correctKo;
    final explanation = generateExplanation(_currentPatient);

    _feedback = isCorrect
        ? '✅ 정답입니다! ($selectedKo)\n$explanation'
        : '❌ 오답입니다. 정답: $correctKo\n$explanation';

    _answered = true;
    _patientCount++;
    if (isCorrect) _correctCount++;

    // 분류 완료 환자 스냅샷(카드 복원용)
    final copied = Map<String, dynamic>.from(_currentPatient);
    copied['triage_en'] ??=
        _koToEn[copied['정답']] ?? _koToEn[_enToKo[copied['정답']] ?? ''] ?? '';
    _classifiedPatients.add(copied);

    // 세션 기록 추가(초 단위) + 내가 고른 답/정답(EN 코드)
    if (_patientStartTime != null) {
  final elapsedSec =
      DateTime.now().difference(_patientStartTime!).inMilliseconds / 1000.0;
  _sessionRecords.add({
    'patient': _patientCount,
    'time': double.parse(elapsedSec.toStringAsFixed(1)), // ← 0.1초 단위
    'myAnswer': _koToEn[selectedKo] ?? selectedKo,       // 예: "Red"
    'correctAnswer': _koToEn[correctKo] ?? correctKo,    // 예: "Yellow"
  });
}
  });
}


  // ---------------- UI ----------------
  Widget _buildPatientCard() {
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
                if (_currentPatient['image'] != null)
                  Image.asset(
                    _currentPatient['image'],
                    width: 180,
                    height: 220,
                    fit: BoxFit.contain,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🗣 ${_currentPatient['speech']}', style: const TextStyle(fontSize: 16)),
                      Text('🩸 증상: ${_currentPatient['injury']}',
                          style: TextStyle(color: Colors.red[700])),
                      const SizedBox(height: 8),
                      Text('🧑 성별: ${_currentPatient['gender']}'),
                      Text('🎂 나이: ${_currentPatient['age']}세'),
                      const Text('🚶 보행: 불가'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            const Text('🚑 START 평가', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('🟥 R (Respiration)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('• 호흡수: ${_currentPatient['호흡수']} 회/분'),
                if (_currentPatient['호흡수'] == 0 && _currentPatient['needAirway'] == true)
                  const SizedBox(width: 12),
                if (_currentPatient['호흡수'] == 0 && _currentPatient['needAirway'] == true)
                  ElevatedButton(
                    onPressed: _currentPatient['기도결과'] == null ? _checkAirway : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text('기도 개방'),
                  ),
              ],
            ),
            if (_currentPatient['기도결과'] != null)
              Text('• 기도개방 시도: ${_currentPatient['기도결과']}'),
            const SizedBox(height: 8),
            const Text('🟨 P (Perfusion)', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• 모세혈관 충혈 시간: ${_currentPatient['refillTime']}초'),
            Text('• 말초맥박: ${_currentPatient['hasPulse'] ? '촉지됨' : '촉지 안됨'}'),
            const SizedBox(height: 8),
            const Text('🟦 M (Mental Status)', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• 의식 수준(AVPU): ${_currentPatient['mentalStatus']}'),
            Text('• 지시 수행: ${_currentPatient['followsCommand'] ? '지시에 따름' : '수행 불가'}'),
            if (_feedback != null) ...[
              const SizedBox(height: 12),
              Text('👉 $_feedback', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChoices() {
    final options = ['긴급', '응급', '비응급', '사망'];
    final disabled = _answered ||
        (_currentPatient['needAirway'] == true &&
         _currentPatient['호흡수'] == 0 &&
         _currentPatient['기도결과'] == null);
    return Wrap(
      spacing: 8,
      children: options.map((ko) {
        final bg = _colorFor(ko);
        final fg = ko == '사망' ? Colors.white : Colors.black;
        return ElevatedButton(
          onPressed: disabled ? null : () => _checkAnswer(ko),
          style: ElevatedButton.styleFrom(backgroundColor: bg),
          child: Text(ko, style: TextStyle(color: fg, fontWeight: FontWeight.bold)),
        );
      }).toList(),
    );
  }

  Future<void> _onNextOrFinish() async {
    final finished = _patientCount >= _maxPatients;
    if (finished) {
      // 복사본 확보(다음 페이지에서 보기용)
      final sessionRecordsCopy   = List<Map<String, dynamic>>.from(_sessionRecords);
      final classifiedPatientsCopy = List<Map<String, dynamic>>.from(_classifiedPatients);

      await _saveSessionOnce(); // 중복 저장 방지

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TreatmentSelectPage(
            classifiedPatients: classifiedPatientsCopy,
            sessionRecords: sessionRecordsCopy,
            // onSessionSaved는 넘기지 않음(중복 방지)
          ),
        ),
      );
    } else {
      _loadNextPatient();
    }
  }

  @override
  Widget build(BuildContext context) {
    final finished = _patientCount >= _maxPatients;

    return Scaffold(
      appBar: AppBar(title: const Text('TimeSaver START 분류')),
      body: _patients.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Text('총 $_patientCount / $_maxPatients명'),
                  _buildPatientCard(),
                  const SizedBox(height: 10),
                  const Text('🚨 분류 선택'),
                  _buildChoices(),
                  if (_answered)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ElevatedButton(
                        onPressed: _savingSession ? null : _onNextOrFinish,
                        child: Text(finished ? '환자 분류 완료' : '다음 환자'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
