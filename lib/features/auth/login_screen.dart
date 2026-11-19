
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../shared/hisaab_logo.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phone = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();

  String _dialCode = '+91';

  static const Color _green = Color(0xFF087B50);
  static const Color _darkGreen = Color(0xFF064E38);
  static const Color _background = Color(0xFFF5F8F6);
  static const Color _border = Color(0xFFE7EEE9);

  @override
  void dispose() {
    _phone.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final number = _phone.text.trim();

    if (!RegExp(r'^\d{7,14}$').hasMatch(number)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enter a valid mobile number'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _darkGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
      return;
    }

    final fullPhone = '$_dialCode$number';
    final auth = context.read<HisaabAuthProvider>();

    _phoneFocus.unfocus();

    await auth.sendOtp(fullPhone);

    if (!mounted) return;

    if (auth.error == null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(phone: fullPhone),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().strings;
    final auth = context.watch<HisaabAuthProvider>();

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          // Premium green background
          Container(
            height: MediaQuery.of(context).size.height * 0.43,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF075C40),
                  Color(0xFF087B50),
                  Color(0xFF119768),
                ],
              ),
            ),
          ),

          // Decorative background circles
          Positioned(
            top: -95,
            right: -75,
            child: _circle(230, Colors.white.withValues(alpha: 0.045)),
          ),
          Positioned(
            top: 105,
            left: -85,
            child: _circle(170, Colors.white.withValues(alpha: 0.045)),
          ),
          Positioned(
            top: 220,
            right: 30,
            child: _circle(65, Colors.white.withValues(alpha: 0.04)),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 32),

                        // Brand header
                        const HisaabLogo(size: 68),

                        const SizedBox(height: 17),

                        const Text(
                          'Hisaab',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 31,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.1,
                          ),
                        ),

                        const SizedBox(height: 7),

                        Text(
                          'Your money. Your records. Your control.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 13,
                            letterSpacing: 0.2,
                          ),
                        ),

                        const SizedBox(height: 44),

                        // Login card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(
                            23, 27, 23, 23,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF123D2C)
                                    .withValues(alpha: 0.10),
                                blurRadius: 35,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Card heading
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF5EF),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Icon(
                                  Icons.lock_person_rounded,
                                  color: _green,
                                  size: 25,
                                ),
                              ),

                              const SizedBox(height: 21),

                              Text(
                                s.t('welcome'),
                                style: const TextStyle(
                                  color: Color(0xFF172B22),
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.7,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Text(
                                'Enter your mobile number to securely '
                                'access your Hisaab account.',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                  height: 1.6,
                                ),
                              ),

                              const SizedBox(height: 29),

                              // Phone label
                              Row(
                                children: [
                                  Text(
                                    s.t('phone'),
                                    style: const TextStyle(
                                      color: Color(0xFF263B30),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Text(
                                    '*',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 11),

                              // Phone input
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 59,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAF8),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(color: _border),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _dialCode,
                                        borderRadius: BorderRadius.circular(15),
                                        icon: const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 18,
                                          color: Colors.black54,
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: '+91',
                                            child: Text(
                                              '🇮🇳 +91',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: '+1',
                                            child: Text(
                                              '🇺🇸 +1',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: '+44',
                                            child: Text(
                                              '🇬🇧 +44',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                        onChanged: auth.loading
                                            ? null
                                            : (value) {
                                                if (value != null) {
                                                  setState(() {
                                                    _dialCode = value;
                                                  });
                                                }
                                              },
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  Expanded(
                                    child: SizedBox(
                                      height: 59,
                                      child: TextField(
                                        controller: _phone,
                                        focusNode: _phoneFocus,
                                        enabled: !auth.loading,
                                        keyboardType: TextInputType.phone,
                                        maxLength: 14,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                          color: Color(0xFF172B22),
                                        ),
                                        decoration: InputDecoration(
                                          hintText: s.t('enterPhone'),
                                          hintStyle: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 13,
                                            fontWeight: FontWeight.normal,
                                          ),
                                          counterText: '',
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAF8),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 15,
                                            vertical: 19,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            borderSide: const BorderSide(
                                              color: _border,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            borderSide: const BorderSide(
                                              color: _border,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            borderSide: const BorderSide(
                                              color: _green,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Authentication error
                              if (auth.error != null) ...[
                                const SizedBox(height: 13),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF0F0),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        color: Colors.red,
                                        size: 19,
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Text(
                                          auth.error!,
                                          style: const TextStyle(
                                            color: Color(0xFFB42318),
                                            fontSize: 12,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 24),

                              // Continue button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: FilledButton(
                                  onPressed:
                                      auth.loading ? null : _sendOtp,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _green,
                                    disabledBackgroundColor:
                                        _green.withValues(alpha: 0.6),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: auth.loading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              s.t('continue'),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            const Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 19,
                                            ),
                                          ],
                                        ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Security message
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.verified_user_rounded,
                                    color: _green.withValues(alpha: 0.8),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Text(
                                      'Your account is protected with OTP verification',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Language selector
                        const _LanguagePicker(),

                        const SizedBox(height: 22),

                        // Terms
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: Text(
                            'By continuing, you agree to our Terms & Privacy Policy.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Text(
                          'MADE FOR BETTER MONEY MANAGEMENT',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 9,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker();

  static const Color _green = Color(0xFF087B50);

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LanguageProvider>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE7EEE9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.language_rounded,
            size: 18,
            color: _green,
          ),
          const SizedBox(width: 9),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: p.locale,
              borderRadius: BorderRadius.circular(14),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 19,
              ),
              style: const TextStyle(
                color: Color(0xFF263B30),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'en',
                  child: Text('English'),
                ),
                DropdownMenuItem(
                  value: 'hi',
                  child: Text('हिन्दी'),
                ),
                DropdownMenuItem(
                  value: 'mr',
                  child: Text('मराठी'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  p.setLanguage(value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
