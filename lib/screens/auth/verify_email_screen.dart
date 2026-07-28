import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../auth_wrapper.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _authService = AuthService();
  static const Color _teal = Color(0xFF0F766E);

  Timer? _timer;
  bool _canResend = true;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkVerified());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified({bool manual = false}) async {
    await _authService.reloadAndCheckVerified();
    final verified = _authService.currentUser?.emailVerified ?? false;

    if (verified && mounted) {
      _timer?.cancel();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
      );
    } else if (manual && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          title: const Text('Almost there'),
          content: const Text(
            'If you clicked the verification link, please log in again to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await _authService.logout();
              },
              child: const Text('Log in again'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _resendEmail() async {
    await _authService.sendVerificationEmail();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verification email sent again.'),
        backgroundColor: _teal,
        behavior: SnackBarBehavior.floating,
      ),
    );

    setState(() {
      _canResend = false;
      _resendCountdown = 30;
    });

    Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown == 0) {
        t.cancel();
        if (mounted) setState(() => _canResend = true);
      } else {
        if (mounted) setState(() => _resendCountdown--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = _authService.currentUser?.email ?? 'your email';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () async {
            // Logout karke login screen pe wapas
            await _authService.logout();
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App logo
              Center(
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 80,
                  height: 80,
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Verify your email',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                "We've sent a verification link to\n$email",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Open the link, then come back here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _teal),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Waiting for verification...',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // I've verified button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _checkVerified(manual: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    "I've verified my email",
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Resend button
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _canResend ? _resendEmail : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _teal,
                    side: const BorderSide(color: _teal),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    _canResend
                        ? 'Resend email'
                        : 'Resend in ${_resendCountdown}s',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Logout option
              TextButton(
                onPressed: () async {
                  await _authService.logout();
                },
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280)),
                child: const Text('Use a different account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}