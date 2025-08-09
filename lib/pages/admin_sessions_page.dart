// lib/pages/admin_sessions_page.dart
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

class AdminSessionsPage extends StatefulWidget {
  final String profileId;
  final String displayName;
  final String code;

  const AdminSessionsPage({
    super.key,
    required this.profileId,
    required this.displayName,
    required this.code,
  });

  @override
  State<AdminSessionsPage> createState() => _AdminSessionsPageState();
}

class _AdminSessionsPageState extends State<AdminSessionsPage> {
  bool _exporting = false;
  bool _deleting = false;

  Future<void> _exportSessionsCsv(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내보낼 세션이 없습니다.')),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      final rows = <List<dynamic>>[
        ['sessionId', 'sessionStart', 'endedAt', 'total', 'correct', 'accuracy', 'avgTimeMs'],
        ...docs.map((d) {
          final m = d.data();
          return [
            d.id,
            m['sessionStart'] ?? '',
            m['endedAt'] ?? '',
            m['total'] ?? '',
            m['correct'] ?? '',
            m['accuracy'] ?? '',
            m['avgTimeMs'] ?? '',
          ];
        }),
      ];
      final csv = const ListToCsvConverter().convert(rows);
      final bytes = Uint8List.fromList(csv.codeUnits);

      await FileSaver.instance.saveFile(
        name: 'sessions_${widget.displayName}_${widget.code}_${DateTime.now().toIso8601String()}',
        bytes: bytes,
        ext: 'csv',
        mimeType: MimeType.csv,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('CSV 저장 완료')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('CSV 저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _deleteUserAndSessions() async {
    // 확인 모달
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('대원 삭제'),
        content: Text(
          '정말로 "${widget.displayName} (${widget.code})" 대원을 삭제할까요?\n'
          '이 대원의 모든 세션 기록도 함께 삭제됩니다.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _deleting = true);
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(widget.profileId);
      final sessionsRef = userRef.collection('sessions');

      // 세션 하위컬렉션 모두 삭제 (배치 + 페이지네이션)
      const pageSize = 300;
      while (true) {
        final page = await sessionsRef.limit(pageSize).get();
        if (page.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in page.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      // 사용자 문서 삭제
      await userRef.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 완료: ${widget.displayName} (${widget.code})')),
      );
      Navigator.pop(context); // 목록 화면으로 복귀
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.profileId)
        .collection('sessions')
        .orderBy('savedAt', descending: true)
        .limit(200)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? {},
          toFirestore: (data, _) => data,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text('세션 기록 - ${widget.displayName} (${widget.code})'),
        actions: [
          // CSV 내보내기
          IconButton(
            tooltip: 'CSV 내보내기(세션 요약)',
            onPressed: _exporting || _deleting
                ? null
                : () async {
                    final qs = await sessions.get();
                    await _exportSessionsCsv(qs.docs);
                  },
            icon: _exporting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download),
          ),
          // 대원 삭제
          IconButton(
            tooltip: '대원 삭제',
            onPressed: _deleting || _exporting ? null : _deleteUserAndSessions,
            icon: _deleting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: sessions.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('오류: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('세션 기록이 없습니다.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final d = docs[i];
              final m = d.data();

              final sessionStart = (m['sessionStart'] ?? '') as String;
              final endedAt = (m['endedAt'] ?? '') as String;
              final total = (m['total'] ?? 0) as int;
              final correct = (m['correct'] ?? 0) as int;

              final accuracy = (m['accuracy'] ?? 0.0);
              final accPct = (accuracy is num) ? (accuracy * 100) : 0.0;

              int avgTimeMs = (m['avgTimeMs'] ?? 0) as int;
              final records =
                  (m['records'] as List?)?.cast<Map<String, dynamic>>() ??
                      (m['records'] is List
                          ? List<Map<String, dynamic>>.from(
                              (m['records'] as List).map(
                                (e) => Map<String, dynamic>.from(e as Map),
                              ),
                            )
                          : <Map<String, dynamic>>[]);
              if (avgTimeMs == 0 && records.isNotEmpty) {
                final sumSec = records.fold<int>(0, (a, r) => a + ((r['time'] ?? 0) as int));
                avgTimeMs = total > 0 ? ((sumSec * 1000) / total).round() : 0;
              }

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    '세션 ${i + 1}  •  환자 $total명  •  정답 $correct명  •  정답률 ${accPct is num ? accPct.toStringAsFixed(1) : "-"}%',
                  ),
                  subtitle: Text(
                    '평균시간 ${(avgTimeMs / 1000).toStringAsFixed(1)}초  •  시작 $sessionStart  •  종료 $endedAt',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _RecordsTable(records: records),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RecordsTable extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  const _RecordsTable({required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Text('환자별 기록이 없습니다.');
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: const [
              SizedBox(width: 60, child: Text('환자', style: TextStyle(fontWeight: FontWeight.bold))),
              SizedBox(width: 100, child: Text('분류시간(초)', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('정오', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        ...records.map((r) {
          final p = r['patient'];
          final timeSec = (r['time'] ?? 0) as int;
          final correct = (r['correct'] ?? 0) as int;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(width: 60, child: Text('$p')),
                SizedBox(width: 100, child: Text(timeSec.toString())),
                Expanded(child: Text(correct == 1 ? '정답' : '오답')),
              ],
            ),
          );
        }),
      ],
    );
  }
}
