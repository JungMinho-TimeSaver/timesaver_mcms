// lib/profile_setup.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 선택사항: 프로필 저장 시 Firestore에도 동기화
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileSetupPage extends StatefulWidget {
  final VoidCallback onDone;
  const ProfileSetupPage({super.key, required this.onDone});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameC = TextEditingController();
  final TextEditingController codeC = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prefillIfAny();
  }

  Future<void> _prefillIfAny() async {
    final prefs = await SharedPreferences.getInstance();
    nameC.text = prefs.getString('profile_name') ?? '';
    codeC.text = prefs.getString('profile_code') ?? '';
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    nameC.dispose();
    codeC.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    final name = nameC.text.trim();
    final code = codeC.text.trim();

    setState(() => _saving = true);
    try {
      // 1) 로컬 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_name', name);
      await prefs.setString('profile_code', code);

      // 2) (선택) Firestore 동기화: users/{uid}
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'name': name,
            'code': code,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (_) {
        // 내부용이니 조용히 스킵(네트워크 이슈 등)
      }

      if (!mounted) return;

      // 3) 상위 라우트에 완료 알림 (ProfileGate → HomePage 전환)
      widget.onDone();

      // 4) 편집 진입이었다면 이전 화면으로 복귀
      await Future.delayed(const Duration(milliseconds: 80));
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('사용자 설정')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: nameC,
                    decoration: const InputDecoration(
                      labelText: '이름',
                      hintText: '예: 정민호',
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return '이름을 입력하세요.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: codeC,
                    decoration: const InputDecoration(
                      labelText: '숫자 4자리 (전화번호 뒤 4자리 추천)',
                      counterText: '',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    maxLength: 4,
                    onFieldSubmitted: (_) => _saveProfile(),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.length != 4 || int.tryParse(t) == null) {
                        return '숫자 4자리여야 합니다. (전화번호 뒤 4자리 추천)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _saveProfile,
                      child: _saving
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('저장'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '※ 이름/코드는 홈 상단과 랭킹 식별에만 사용됩니다.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
