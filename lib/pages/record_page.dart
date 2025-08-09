import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // 초기화면(HomePage) 이동
import 'package:intl/intl.dart';

class RecordPage extends StatefulWidget {
  @override
  _RecordPageState createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final savedList = prefs.getStringList('session_records') ?? [];

    setState(() {
      _records = savedList
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .where((record) => (record['total'] ?? 0) > 0) // 🔹 빈 세션 제거
          .toList()
          .reversed
          .toList();
    });
  }

  Future<void> _clearAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_records');
    setState(() => _records.clear());
  }

  /// 🔹 날짜 변환 함수
  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return '-';
    try {
      final dt = DateTime.tryParse(value.toString());
      if (dt == null) return value.toString();
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  /// 🔹 환자별 세부 기록
  Widget _buildPatientDetails(List<dynamic> patients) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: patients.map((p) {
        final idx = p['patient'];
        final correct = p['correct'] == 1 ? '정답' : '오답';
        final time = p['time'] ?? 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text('환자 $idx → $correct (${time}초)',
              style: TextStyle(fontSize: 14)),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('세션 기록')),
      body: _records.isEmpty
          ? Center(child: Text('기록 없음'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(8),
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      final patients = record['patients'] ?? [];
                      final total = record['total'] ?? 0;
                      final correct = record['correct'] ?? 0;
                      final accuracy = record['accuracy'] ?? '0';
                      final avgTime = record['avgTime'] ?? '0.0';
                      final startTime = record['startTime'] ?? record['timestamp'];
                      final endTime = record['endTime'] ?? record['timestamp'];

                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 6),
                        color: Colors.purple[50],
                        child: ExpansionTile(
                          title: Text(
                            '세션 ${_records.length - index}',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '시작: ${_formatDate(startTime)}\n'
                            '종료: ${_formatDate(endTime)}\n'
                            '총 $total명, 정답 $correct명\n'
                            '정확도 $accuracy%, 평균 $avgTime초',
                          ),
                          children: [
                            if (patients.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 16, right: 16, bottom: 8),
                                child: _buildPatientDetails(patients),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // 🔹 하단 버튼
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => HomePage()),
                            (route) => false,
                          );
                        },
                        child: Text('초기화면으로'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _clearAllRecords,
                        child: Text('모든 기록 삭제'),
                      ),
                    ],
                  ),
                )
              ],
            ),
    );
  }
}
