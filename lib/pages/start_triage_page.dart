import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pages/record_page.dart';           // 기록 보기 화면
import '../pages/treatment_mode_page.dart';   // 처치반 모드 화면
import 'treatment_select_page.dart';

class StartTriagePage extends StatefulWidget {
  @override
  _StartTriagePageState createState() => _StartTriagePageState();
}

class _StartTriagePageState extends State<StartTriagePage> {
  final Random _random = Random();
  List<Map<String, dynamic>> _patients = [];
  Map<String, dynamic> _currentPatient = {};
  String? _selectedAnswer;
  String? _feedback;
  bool _answered = false;

  // 세션 기록용
  DateTime? _patientStartTime;
  DateTime? _sessionStartTime;       // 🔹 세션 시작 시각 (여기에 추가)
  List<Map<String, dynamic>> _sessionRecords = [];
  List<Map<String, dynamic>> _classifiedPatients = [];

  int _correctCount = 0;
  int _patientCount = 0;
  final int _maxPatients = 5;

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();   // 🔹 세션 시작 시간 기록
    _loadPatients();
  }

  // ✅ 세션 저장
  Future<void> _saveSessionToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> existing = prefs.getStringList('session_records') ?? [];

    final total = _sessionRecords.length;
    final correctCount = _sessionRecords.where((r) => r['correct'] == 1).length;
    final avgTime = total > 0
        ? _sessionRecords.map((r) => r['time'] as int).reduce((a, b) => a + b) / total
        : 0;

    final sessionData = {
      'sessionStart': _sessionStartTime?.toIso8601String() ?? '',
      'timestamp': DateTime.now().toIso8601String(),
      'total': total,
      'correct': correctCount,
      'accuracy': (total > 0 ? correctCount / total * 100 : 0).toStringAsFixed(1),
      'avgTime': avgTime.toStringAsFixed(1),
      'patients': _sessionRecords,
    };
    existing.add(jsonEncode(sessionData));
    await prefs.setStringList('session_records', existing);

    // 초기화
    _sessionRecords.clear();
  }

  // ✅ 해설 생성
  String generateExplanation(Map<String, dynamic> p) {
    final int rr = p['호흡수'];
    final double crt = double.parse(p['refillTime']);
    final bool pulse = p['hasPulse'];
    final String mental = p['mentalStatus'];
    final bool follow = p['followsCommand'];

    List<String> reasons = [];

    // R
    if (rr == 0) {
      return p['기도결과'] == '호흡 확인됨'
          ? '기도개방 후 호흡 확인 → Red'
          : '호흡 없음, 맥박 없음 → Black';
    }
    if (rr > 30) reasons.add('호흡수 $rr회/분 → Red (호흡수 과다)');

    // P
    if (!pulse || crt > 2.0) reasons.add('모세혈관충혈 ${crt}초 또는 맥박 없음 → Red');

    // M
    if (mental == 'U') reasons.add('의식 없음(U) → Red');
    else if (!follow) reasons.add('지시 수행 불가 → Yellow');

    if (reasons.isEmpty) {
      return '호흡·순환·의식 정상 → ${p['canWalk'] ? 'Green' : 'Yellow'}';
    }

    return reasons.join('\n');
  }

  // ✅ 환자 로드
  Future<void> _loadPatients() async {
    final String jsonString = await rootBundle.loadString('assets/patients/generated_patients.json');
    final List<dynamic> jsonList = json.decode(jsonString);
    setState(() {
      _patients = jsonList.cast<Map<String, dynamic>>();
    });
    _loadNextPatient();
  }

  void _loadNextPatient() {
  if (_patients.isEmpty) return;

  // ✅ 첫 환자 로드 시 세션 시작 시간 기록
  if (_patientCount == 0 && _sessionStartTime == null) {
    _sessionStartTime = DateTime.now();
  }

  final patient = Map<String, dynamic>.from(
      _patients[_random.nextInt(_patients.length)]);

    // 랜덤 값 생성
    patient['호흡수'] = _random.nextInt(
            patient['breathingRange'][1] - patient['breathingRange'][0] + 1) +
        patient['breathingRange'][0];
    patient['age'] = _random.nextInt(
            patient['ageRange'][1] - patient['ageRange'][0] + 1) +
        patient['ageRange'][0];
    patient['refillTime'] = (_random.nextDouble() *
                (patient['refillTimeRange'][1] -
                    patient['refillTimeRange'][0]) +
            patient['refillTimeRange'][0])
        .toStringAsFixed(1);

    patient['canWalk'] = false;

    // START 분류 알고리즘
    if (patient['호흡수'] == 0 && patient['needAirway']) {
  patient['정답'] = null; // 기도 시도 전까지 정답 없음
} else if (
    patient['호흡수'] > 30 || 
    patient['호흡수'] < 10 ||       // 🔹 추가: RR < 10 → Red
    double.parse(patient['refillTime']) > 2.0 ||
    patient['hasPulse'] == false
) {
  patient['정답'] = 'Red';
} else if (patient['mentalStatus'] == 'U') {
  patient['정답'] = 'Red';
} else if (!patient['followsCommand']) {
  patient['정답'] = 'Yellow';
} else {
  patient['정답'] = patient['canWalk'] ? 'Green' : 'Yellow';
}

    // 화면 상태 갱신
    setState(() {
      _selectedAnswer = null;
      _feedback = null;
      _answered = false;
      _currentPatient = patient;
      _currentPatient['기도결과'] = null;
      _patientStartTime = DateTime.now();
    });
  }

  // ✅ 기도 확인
  void _checkAirway() {
    final result = _random.nextBool() ? '호흡 확인됨' : '호흡 없음';
    setState(() {
      _currentPatient['기도결과'] = result;
      if (_currentPatient['호흡수'] == 0 && result == '호흡 확인됨') {
        _currentPatient['정답'] = 'Red';
      } else if (_currentPatient['호흡수'] == 0 && result == '호흡 없음') {
        _currentPatient['정답'] = 'Black';
      }
    });
  }

void _checkAnswer(String selected) {
  if (_answered || (_currentPatient['호흡수'] == 0 && _currentPatient['기도결과'] == null)) return;

  setState(() {
    _selectedAnswer = selected;
    final isCorrect = selected == _currentPatient['정답'];
    final explanation = generateExplanation(_currentPatient);

    _feedback = isCorrect
        ? '✅ 정답입니다! ($selected)\n$explanation'
        : '❌ 오답입니다. 정답: ${_currentPatient['정답']}\n$explanation';

    _answered = true;
    _patientCount++;
    if (isCorrect) _correctCount++;

    // 🔹 분류 완료 환자 기록
    _classifiedPatients.add(Map.from(_currentPatient));

    // 🔹 세션 기록 추가
    if (_patientStartTime != null) {
      final duration = DateTime.now().difference(_patientStartTime!).inSeconds;
      _sessionRecords.add({
        'patient': _patientCount,
        'time': duration,
        'correct': isCorrect ? 1 : 0,
      });
    }
  });

  // ❌ 여기서 다음 환자 로드 X → 버튼으로 이동
}
  

  // ✅ 환자 카드
  Widget _buildPatientCard() {
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
                if (_currentPatient['image'] != null)
                  Image.asset(
                    _currentPatient['image'],
                    width: 180,
                    height: 220,
                    fit: BoxFit.contain,
                  ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🗣 ${_currentPatient['speech']}', style: TextStyle(fontSize: 16)),
                      Text('🩸 증상: ${_currentPatient['injury']}', style: TextStyle(color: Colors.red[700])),
                      SizedBox(height: 8),
                      Text('🧑 성별: ${_currentPatient['gender']}'),
                      Text('🎂 나이: ${_currentPatient['age']}세'),
                      Text('🚶 보행: 불가'),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Divider(),
            Text('🚑 START 평가', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('🟥 R (Respiration)', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Row(
              children: [
                Text('• 호흡수: ${_currentPatient['호흡수']} 회/분'),
                if (_currentPatient['호흡수'] == 0 && _currentPatient['needAirway'] == true)
                  SizedBox(width: 12),
                if (_currentPatient['호흡수'] == 0 && _currentPatient['needAirway'] == true)
                  ElevatedButton(
                    onPressed: _currentPatient['기도결과'] == null ? _checkAirway : null,
                    child: Text('기도 개방'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            if (_currentPatient['기도결과'] != null)
              Text('• 기도개방 시도: ${_currentPatient['기도결과']}'),
            SizedBox(height: 8),
            Text('🟨 P (Perfusion)', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• 모세혈관 충혈 시간: ${_currentPatient['refillTime']}초'),
            Text('• 말초맥박: ${_currentPatient['hasPulse'] ? '촉지됨' : '촉지 안됨'}'),
            SizedBox(height: 8),
            Text('🟦 M (Mental Status)', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• 의식 수준(AVPU): ${_currentPatient['mentalStatus']}'),
            Text('• 지시 수행: ${_currentPatient['followsCommand'] ? '지시에 따름' : '수행 불가'}'),
            if (_feedback != null) ...[
              SizedBox(height: 12),
              Text('👉 $_feedback', style: TextStyle(fontWeight: FontWeight.bold)),
            ]
          ],
        ),
      ),
    );
  }

  // ✅ 선택 버튼
  Widget _buildChoices() {
    final options = ['Red', 'Yellow', 'Green', 'Black'];
    final disabled = _answered ||
        (_currentPatient['needAirway'] == true &&
         _currentPatient['호흡수'] == 0 &&
         _currentPatient['기도결과'] == null);
    return Wrap(
      spacing: 8,
      children: options.map((choice) {
        return ElevatedButton(
          onPressed: disabled ? null : () => _checkAnswer(choice),
          style: ElevatedButton.styleFrom(
            backgroundColor: choice == 'Red'
                ? Colors.red
                : choice == 'Yellow'
                    ? Colors.yellow[700]
                    : choice == 'Green'
                        ? Colors.green
                        : Colors.black,
          ),
          child: Text(
            choice,
            style: TextStyle(
              color: choice == 'Black' ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('TimeSaver START 분류')),
      body: _patients.isEmpty
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 10),
                  Text('총 $_patientCount / $_maxPatients명'),
                  _buildPatientCard(),
                  SizedBox(height: 10),
                  Text('🚨 분류 선택'),
                  _buildChoices(),
                  if (_answered)
  Padding(
    padding: const EdgeInsets.only(top: 12),
    child: ElevatedButton(
      onPressed: () async {
        if (_patientCount >= _maxPatients) {
          // 세션 저장 후 처치반 선택 페이지 이동
          await _saveSessionToPrefs();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TreatmentSelectPage(
                classifiedPatients: _classifiedPatients,
                sessionRecords: _sessionRecords,
                onSessionSaved: _saveSessionToPrefs,
              ),
            ),
          );
        } else {
          // 다음 환자 로드
          _loadNextPatient();
        }
      },
      child: Text(_patientCount >= _maxPatients ? '환자 분류 완료' : '다음 환자'),
    ),
  )
                ],
              ),
            ),
    );
  }
}
