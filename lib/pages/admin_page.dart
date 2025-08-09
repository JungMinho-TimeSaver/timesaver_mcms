import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

// makeProfileId 재사용
import '../main.dart' show makeProfileId;
// 상세 페이지
import 'admin_user_detail_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  String _keyword = '';
  bool _sortByAvgTime = false; // false: 점수 내림차순, true: 평균시간 오름차순
  bool _exporting = false;
  bool _deleting = false;

  Future<void> _exportCsv(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내보낼 데이터가 없습니다.')),
      );
      return;
    }

    setState(() => _exporting = true);
    try {
      final rows = <List<dynamic>>[
        ['name', 'code', 'totalScore', 'avgTimeMs', 'count', 'updatedAt', 'profileId'],
        ...docs.map((d) {
          final m = d.data();
          final name = (m['name'] ?? '').toString();
          final code = (m['code'] ?? '').toString();
          final pid  = makeProfileId(name, code);
          return [
            name,
            code,
            m['totalScore'] ?? 0,
            m['avgTimeMs'] ?? '',
            m['count'] ?? '',
            (m['updatedAt'] is Timestamp)
                ? (m['updatedAt'] as Timestamp).toDate().toIso8601String()
                : '',
            pid,
          ];
        }),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final bytes = Uint8List.fromList(csv.codeUnits);

      await FileSaver.instance.saveFile(
        name: 'MCI_users_${DateTime.now().toIso8601String()}',
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

  Future<void> _deleteUserCascade(String profileId, String displayName, String code) async {
    if (_deleting) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('대원 삭제'),
        content: Text('[$displayName ($code)] 대원의 모든 기록을 삭제할까요?\n(사용자 문서와 모든 세션이 삭제됩니다)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _deleting = true);
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(profileId);
      final qs = await userRef.collection('sessions').get();
      // 하위 세션 모두 삭제
      for (final doc in qs.docs) {
        await doc.reference.delete();
      }
      // 사용자 문서 삭제
      await userRef.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('대원을 삭제했습니다.')),
      );
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
    final col = FirebaseFirestore.instance.collection('users');
    final query = _sortByAvgTime
        ? col.orderBy('avgTimeMs').limit(500)
        : col.orderBy('totalScore', descending: true).limit(500);

    return Scaffold(
      appBar: AppBar(title: const Text('관리자 페이지')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔎 필터 & 정렬
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '이름 또는 코드 검색',
                    ),
                    onChanged: (v) => setState(() => _keyword = v.trim()),
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: const Text('평균시간 기준'),
                  selected: _sortByAvgTime,
                  onSelected: (v) => setState(() => _sortByAvgTime = v),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 📊 목록
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: query.snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('오류: ${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final all = snap.data!.docs;

                  // 키워드 필터
                  final filtered = all.where((d) {
                    if (_keyword.isEmpty) return true;
                    final m = d.data();
                    final name = (m['name'] ?? '').toString();
                    final code = (m['code'] ?? '').toString();
                    final kw = _keyword.toLowerCase();
                    return name.toLowerCase().contains(kw) ||
                        code.toLowerCase().contains(kw);
                  }).toList();

                  // 간단 집계
                  final totalUsers = filtered.length;
                  final sumScore = filtered.fold<int>(
                      0, (a, d) => a + ((d.data()['totalScore'] ?? 0) as int));
                  final avgOfAvgTimeMs = filtered.isEmpty
                      ? 0
                      : (filtered.fold<int>(
                                  0,
                                  (a, d) =>
                                      a + ((d.data()['avgTimeMs'] ?? 0) as int)) /
                              filtered.length)
                          .round();

                  return Column(
                    children: [
                      Row(
                        children: [
                          Text('총 $totalUsers명',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _sortByAvgTime
                                  ? '평균시간(평균): ${avgOfAvgTimeMs > 0 ? (avgOfAvgTimeMs / 1000).toStringAsFixed(1) : "-"}초'
                                  : '누적점수 합계: $sumScore',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed:
                                _exporting ? null : () => _exportCsv(filtered),
                            icon: _exporting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.download),
                            label: const Text('CSV 내보내기'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.black12),
                          ),
                          child: ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final d = filtered[i];
                              final m = d.data();
                              final name = (m['name'] ?? '무명') as String;
                              final code = (m['code'] ?? '') as String;
                              final score = (m['totalScore'] ?? 0) as int;
                              final avgMs = (m['avgTimeMs'] ?? 0) as int?;
                              final count = (m['count'] ?? 0) as int?;
                              final pid = makeProfileId(name, code);

                              return ListTile(
                                leading: Text('${i + 1}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                title: Text('$name (${code.isNotEmpty ? code : "--"})'),
                                subtitle: Text(
                                  _sortByAvgTime
                                      ? '평균시간: ${avgMs != null && avgMs > 0 ? (avgMs / 1000).toStringAsFixed(1) : "-"}초'
                                      : '누적점수: $score • 세션 ${count ?? 0}회',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 삭제 버튼
                                    IconButton(
                                      tooltip: '대원 삭제',
                                      icon: _deleting
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.delete_outline),
                                      onPressed: _deleting
                                          ? null
                                          : () => _deleteUserCascade(pid, name, code),
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AdminUserDetailPage(
                                        profileId: pid,
                                        displayName: name,
                                        displayCode: code,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
