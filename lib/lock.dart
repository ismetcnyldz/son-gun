// Uygulama kilidi: Face ID / parmak izi / telefon şifresi
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

final lockEnabled = ValueNotifier<bool>(false);

Future<void> loadLockSetting() async {
  if (kIsWeb) return;
  final p = await SharedPreferences.getInstance();
  lockEnabled.value = p.getBool('lock_enabled') ?? false;
}

/// Kilidi açıp kapatır. Açmadan önce kullanıcının doğrulama yapabildiğini kontrol eder.
Future<String?> setLockEnabled(bool on) async {
  if (kIsWeb) return 'Kilit web sürümünde yok.';
  if (on) {
    final auth = LocalAuthentication();
    final can = await auth.isDeviceSupported();
    if (!can) return 'Bu telefonda ekran kilidi, parmak izi ya da Face ID ayarlı değil.';
    final ok = await _authenticate();
    if (!ok) return 'Doğrulama yapılmadı.';
  }
  lockEnabled.value = on;
  final p = await SharedPreferences.getInstance();
  await p.setBool('lock_enabled', on);
  return null;
}

Future<bool> _authenticate() async {
  try {
    return await LocalAuthentication().authenticate(
      localizedReason: 'Son Gün\'ü açmak için kimliğini doğrula',
      options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
    );
  } catch (_) {
    return false;
  }
}

/// Kilit açıksa uygulamanın önüne kilit ekranı koyar; arka plandan dönünce yeniden kilitler.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});
  final Widget child;
  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool unlocked = false;
  bool busy = false;
  DateTime? pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unlocked = !lockEnabled.value;
    if (!unlocked) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (!lockEnabled.value || busy) return;
    if (s == AppLifecycleState.paused) pausedAt = DateTime.now();
    if (s == AppLifecycleState.resumed && pausedAt != null && DateTime.now().difference(pausedAt!).inSeconds > 30) {
      pausedAt = null;
      setState(() => unlocked = false);
      _unlock();
    }
  }

  Future<void> _unlock() async {
    if (busy) return;
    busy = true;
    final ok = await _authenticate();
    busy = false;
    if (mounted && ok) setState(() => unlocked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (unlocked || !lockEnabled.value) return widget.child;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_rounded, size: 56, color: C.accent),
              const SizedBox(height: 16),
              Text('Son Gün kilitli', style: display(28)),
              const SizedBox(height: 8),
              Text('Devam etmek için kimliğini doğrula.', style: TextStyle(color: C.muted)),
              const SizedBox(height: 24),
              FilledButton.icon(onPressed: _unlock, icon: const Icon(Icons.fingerprint_rounded), label: const Text('Kilidi aç')),
            ]),
          ),
        ),
      ),
    );
  }
}
