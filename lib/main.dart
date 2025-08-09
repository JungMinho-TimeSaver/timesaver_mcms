// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

// Firestore(관리자 페이지 내 리스트/CSV에서 사용)
import 'package:cloud_firestore/cloud_firestore.dart';

// 페이지들
import 'pages/start_triage_page.dart';
import 'pages/record_page.dart';
import 'pages/admin_page.dart';

// 간단 로그인(프로필 입력) 화면
import 'profile_setup.dart';

/// 이름+코드로 일관된 문서 ID 생성 (소문자/공백 정리)
String makeProfileId(String name, String code) {
  return '${name.trim().toLowerCase()}_${code.trim()}';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 익명 로그인(내부 서비스용)
  await FirebaseAuth.instance.signInAnonymously();

  runApp(const TimeSaverStartApp());
}

class TimeSaverStartApp extends StatelessWidget {
  const TimeSaverStartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '다수사상자 분류 훈련',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const ProfileGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// 앱 시작 시 프로필(이름+4자리) 저장 여부 확인
class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key});

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  bool _loading = true;
  bool _hasProfile = false;

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('profile_name');
    final code = prefs.getString('profile_code');

    // 프로필 유무 먼저 반영
    setState(() {
      _hasProfile = (name != null && code != null);
      _loading = false;
    });

    // 프로필이 있을 때만 users/{profileId} 기본 문서 보장
    if (name != null && code != null) {
      final profileId = makeProfileId(name, code);
      final ref = FirebaseFirestore.instance.collection('users').doc(profileId);
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'name': name,
          'code': code,
          'totalScore': 0,
          'count': 0,        // 세션 수
          'patientSum': 0,   // 누적 환자 수
          'timeSumMs': 0,
          'avgTimeMs': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  void _onProfileDone() => setState(() => _hasProfile = true);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_hasProfile) {
      return ProfileSetupPage(onDone: _onProfileDone);
    }
    return const HomePage();
  }
}

/// 홈 화면: 환영문구 + 분류 시작 / 기록 보기 / 관리자
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _name;
  String? _code;

  static const _ADMIN_PIN = '4763'; // 🔒 임시 관리자 PIN

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('profile_name');
      _code = prefs.getString('profile_code');
    });
  }

  Future<void> _switchProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileSetupPage(onDone: () {})),
    );
    await _loadProfile();

    // Firestore 사용자 문서도 동기화 (ID = name+code)
    final name = _name ?? '무명';
    final code = _code ?? '0000';
    final profileId = makeProfileId(name, code);
    await FirebaseFirestore.instance.collection('users').doc(profileId).set({
      'name': name,
      'code': code,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _openAdmin() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('관리자 인증'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '관리자 PIN',
            hintText: '숫자 4자리',
            counterText: '',
          ),
          keyboardType: TextInputType.number,
          obscureText: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          autofocus: true,
          onSubmitted: (_) => Navigator.pop(context, true),
          maxLength: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (ok == true) {
      if (controller.text.trim() == _ADMIN_PIN) {
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPage()));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('잘못된 PIN입니다.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = (_name != null && _code != null)
        ? '사용자: $_name ($_code)'
        : '사용자 미설정';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text('다수사상자 분류 훈련'),
        actions: [
          if (_name != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Text(
                  '${_name!} 님 환영합니다',
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
              ),
            ),
          IconButton(
            tooltip: '관리자 페이지',
            onPressed: _openAdmin,
            icon: const Icon(Icons.admin_panel_settings_outlined),
          ),
          IconButton(
            tooltip: '사용자 변경',
            onPressed: _switchProfile,
            icon: const Icon(Icons.switch_account),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(subtitle, style: const TextStyle(color: Colors.black54)),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => StartTriagePage()),
                      );
                    },
                    child: const Text('🚑 분류 시작'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RecordPage()),
                      );
                    },
                    child: const Text('📋 기록 보기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
