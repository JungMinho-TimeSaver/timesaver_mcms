// lib/pages/record_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// 홈으로 강제 이동 & profileId 유틸
import '../main.dart' show HomePage, makeProfileId;

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  String? _profileId; // name_code (소문자+언더스코어)

  @override
  void initState() {
    super.initState();
    _loadProfileId();
  }

  Future<void> _loadProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('profile_name');
    final code = prefs.getString('profile_code');
    setState(() {
      _profileId =
          (name != null && code != null) ? makeProfileId(name, code) : null;
    });
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_profileId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('📋 기록 보기'),
          leading: IconButton(
            icon: const Icon(Icons.home),
            tooltip: '초기화면으로',
            onPressed: _goHome,
          ),
        ),
        body: const Center(
          child: Text('사용자 프로필이 없습니다.\n홈에서 프로필을 먼저 설정하세요.'),
        ),
      );
    }

    final sessionsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_profileId)
        .collection('sessions');

    final fmt = DateFormat('yyyy-MM-dd HH:mm:ss');

    DateTime? _fromMs(dynamic v) {
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v).toLocal();
      if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt()).toLocal();
      return null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 기록 보기'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          tooltip: '초기화면으로',
          onPressed: _goHome,
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: sessionsRef.orderBy('savedAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('불러오기 실패: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('저장된 세션이 없습니다.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final docSnap = docs[index];
              final docRef = docSnap.reference;
              final m = docSnap.data();

              final total = (m['total'] ?? 0) as num;
              final correct = (m['correct'] ?? 0) as num;
              final acc = (m['accuracy'] ?? 0.0) as num; // 0..1
              final avgMs = (m['avgTimeMs'] ?? 0) as num;
              final start = _fromMs(m['sessionStartMs']) ??
                  (m['savedAt'] is Timestamp
                      ? (m['savedAt'] as Timestamp).toDate().toLocal()
                      : null);

              final tsText = start != null ? fmt.format(start) : '-';
              final accPct = (acc * 100).toStringAsFixed(1);
              final avgSec = (avgMs / 1000).toStringAsFixed(1);

              return Card(
                elevation: 2,
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  title: Text('세션 ${docs.length - index}  •  $tsText'),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '총 ${total.toInt()}명 / 정답 ${correct.toInt()}명  •  정답률 $accPct%  • 평균시간 ${avgSec}s',
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chevron_right),
                      IconButton(
                        tooltip: '세션 삭제',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('세션 삭제'),
                              content: Text('[$tsText] 세션을 삭제할까요? 되돌릴 수 없습니다.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('취소'),
                                ),
                                FilledButton.tonal(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('삭제'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            try {
                              await docRef.delete();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('세션을 삭제했습니다.')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('삭제 실패: $e')),
                                );
                              }
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    final records  =
                        (m['records']  ?? const <dynamic>[]) as List<dynamic>;
                    final patients =
                        (m['patients'] ?? const <dynamic>[]) as List<dynamic>;
                    _showSessionDetail(context, tsText, records,
                        patients: patients);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ---------------- 상세 모달: 요약 리스트 + 탭하면 카드 펼침 ----------------

  Color _triageColorKo(String ko) {
    switch (ko) {
      case '긴급':
        return Colors.red;
      case '응급':
        return Colors.yellow;
      case '비응급':
        return Colors.green;
      case '사망':
        return Colors.black;
      default:
        return Colors.grey;
    }
  }

 /// START 해설(성인 정상 범위 포함)
/// 세션 상세에서 쓰는 해설(벗어난 기준만 표시)
String _explainFromPatient(Map<String, dynamic> p) {
  final int rr = (p['호흡수'] is num) ? (p['호흡수'] as num).toInt() : 0;
  final double crt =
      (p['refillTime'] is num) ? (p['refillTime'] as num).toDouble()
      : double.tryParse('${p['refillTime'] ?? ''}') ?? 0.0;
  final bool pulse = p['hasPulse'] == true;
  final String mental = (p['mentalStatus'] ?? '').toString();
  final bool follow = p['followsCommand'] == true;

  const String normR  = '10~30회/분';
  const String normCR = '≤2.0초';
  const String normP  = '말초맥박 촉지';
  const String normM  = '지시수행 가능, U 아님';

  final out = <String>[];

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

  if (crt > 2.0) out.add('모세혈관충혈 ${crt.toStringAsFixed(1)}초 (정상 $normCR)');
  if (!pulse) out.add('말초맥박 촉지 안됨 (정상 $normP)');
  if (mental == 'U') out.add('의식 U');
  if (!follow) out.add('지시수행 불가 (정상 $normM)');

  return out.isEmpty ? '모든 항목 정상 범위 내' : out.join('\n');
}



  Widget _patientCardBody(
    Map<String, dynamic> p, {
    String? myAnswer,
    String? correctAnswer,
    double? timeSec,
  }) {
    final triage = (p['정답'] ?? '미분류') as String;
    final triageColor = _triageColorKo(triage);
    final triageText = triage == '사망' ? Colors.white : Colors.black;

    final explanation = _explainFromPatient(p);

    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 내 답/정답/시간
          Row(
            children: [
              if (myAnswer != null) Text('내 답: ${_koFromEn(myAnswer)}'),
              const SizedBox(width: 16),
              if (correctAnswer != null) Text('정답: ${_koFromEn(correctAnswer)}'),
              const SizedBox(width: 16),
              if (timeSec != null) Text('${timeSec.toStringAsFixed(1)}s'),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p['image'] != null && (p['image'] as String).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Image.asset(
                    p['image'],
                    width: 120,
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('🗣 ${p['speech'] ?? '-'}',
                              style: const TextStyle(fontSize: 16)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: triageColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            triage,
                            style: TextStyle(
                                color: triageText, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    Text('🩸 증상: ${p['injury'] ?? '-'}',
                        style: TextStyle(color: Colors.red[700])),
                    const SizedBox(height: 6),
                    Text('🧑 성별: ${p['gender'] ?? '-'}'),
                    Text('🎂 나이: ${p['age'] ?? '-'}세'),
                    Text('🚶 보행: ${(p['canWalk'] == true) ? "가능" : "불가"}'),
                  ],
                ),
              ),
            ],
          ),
          if (p['기도결과'] != null) ...[
            const SizedBox(height: 8),
            Text('• 기도개방 시도: ${p['기도결과']}'),
          ],
          const SizedBox(height: 8),
          const Divider(),
          const Text('START 평가 요약', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('호흡수: ${p['호흡수'] ?? "-"} 회/분'),
          Text('모세혈관충혈: ${(p['refillTime'] ?? "-").toString()} 초'),
          Text('말초맥박: ${(p['hasPulse'] == true) ? "촉지됨" : "촉지 안됨"}'),
          Text('의식(AVPU): ${p['mentalStatus'] ?? "-"} • 지시수행: ${(p['followsCommand'] == true) ? "가능" : "불가"}'),

          const SizedBox(height: 8),
          const Divider(),
          const Text('해설', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(explanation),
        ],
      ),
    );
  }

  // EN → KO 표기
  String _koFromEn(String en) {
    switch (en) {
      case 'Red':
        return '긴급';
      case 'Yellow':
        return '응급';
      case 'Green':
        return '비응급';
      case 'Black':
        return '사망';
      default:
        return en;
    }
  }

  void _showSessionDetail(
    BuildContext context,
    String when,
    List<dynamic> records, {
    List<dynamic>? patients,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final hasPatients = (patients != null && patients.isNotEmpty);

        // records를 환자번호→요약으로 매핑(시간/정오답/내답/정답)
        final Map<int, Map<String, dynamic>> recById = {};
        for (final r in records) {
          if (r is Map) {
            final pid = (r['patient'] ?? 0) as int;
            recById[pid] = {
              'time': (r['time'] is num) ? (r['time'] as num).toDouble() : null,
              'correct': r['correct'],
              'myAnswer': r['myAnswer'],
              'correctAnswer': r['correctAnswer'],
            };
          }
        }

        if (!hasPatients && records.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text('세션 상세 데이터가 없습니다.'),
          );
        }

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('세션 상세 ($when)',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),

                  // ✅ 요약 리스트 + 탭하면 카드 펼침 (해설 포함)
                  Expanded(
                    child: hasPatients
                        ? ListView.builder(
                            controller: controller,
                            itemCount: patients!.length,
                            itemBuilder: (_, i) {
                              final raw = patients[i] as Map;
                              final p = raw
                                  .map((k, v) => MapEntry(k.toString(), v));
                              final pid = (i + 1);
                              final rec = recById[pid];
                              final time = rec?['time'] as double?;
                              final correct = rec?['correct'] == 1;
                              final myAns = rec?['myAnswer'] as String?;
                              final corrAns = rec?['correctAnswer'] as String?;

                              final titleRight = [
                                if (correct) '정답' else '오답',
                                if (time != null) '• ${time.toStringAsFixed(1)}s'
                              ].join(' ');

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ExpansionTile(
                                  title: Text('환자 $pid  •  $titleRight'),
                                  childrenPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  children: [
                                    _patientCardBody(
                                      p,
                                      myAnswer: myAns,
                                      correctAnswer: corrAns,
                                      timeSec: time,
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                        : ListView.separated(
                            controller: controller,
                            itemCount: records.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final r = records[i] as Map<String, dynamic>;
                              final pid = r['patient'] ?? (i + 1);
                              final timeNum = r['time'];
                              final time = (timeNum is num)
                                  ? timeNum.toDouble().toStringAsFixed(1)
                                  : '-';
                              final correct =
                                  (r['correct'] == 1) ? 'O' : 'X';
                              return ListTile(
                                dense: true,
                                title: Text('환자 $pid'),
                                subtitle:
                                    Text('소요시간 ${time}s • 정답여부 $correct'),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
