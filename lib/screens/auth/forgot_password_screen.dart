import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../core/utils/validators.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _emailSent = false;

  static const Color _teal = Color(0xFF0F766E);

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final error = await _authService.resetPassword(_emailController.text);

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (error == null) {
      setState(() => _emailSent = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFB91C1C),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: _emailSent ? _buildSuccessView() : _buildFormView(),
          ),
        ),
      ),
    );
  }

  // Form view — email input
  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),

          // Icon
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.lock_reset, color: _teal, size: 32),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Forgot password?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Enter your email and we'll send you a link to reset your password.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
          ),
          const SizedBox(height: 32),

          TextFormField(
            controller: _emailController,
            validator: Validators.validateEmail,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: const TextStyle(color: Color(0xFF6B7280)),
              prefixIcon: const Icon(Icons.email_outlined,
                  size: 20, color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _teal, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFB91C1C)),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide:
                const BorderSide(color: Color(0xFFB91C1C), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleReset,
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                elevation: 0,
                disabledBackgroundColor: _teal.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Text(
                'Send reset link',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Success view — email sent confirmation
  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 60),

        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.mark_email_read_outlined,
                color: _teal, size: 32),
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "We've sent a password reset link to\n${_emailController.text.trim()}",
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
        ),
        const SizedBox(height: 32),

        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'Back to login',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}