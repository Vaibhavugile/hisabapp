
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
  final _phone = TextEditingController();

  String _dialCode = '+91';

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final number = _phone.text.trim();

    if (!RegExp(r'^\d{7,14}$').hasMatch(number)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid mobile number'),
        ),
      );
      return;
    }

    final fullPhone = '$_dialCode$number';

    final auth = context.read<HisaabAuthProvider>();

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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 22),
                  const HisaabLogo(size: 62),
                  const SizedBox(height: 34),

                  Text(
                    'Hisaab',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    s.t('welcome'),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.black54),
                  ),

                  const SizedBox(height: 38),

                  Text(
                    s.t('phone'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 17,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFFE7ECE8),
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _dialCode,
                            items: const [
                              DropdownMenuItem(
                                value: '+91',
                                child: Text('+91 🇮🇳'),
                              ),
                              DropdownMenuItem(
                                value: '+1',
                                child: Text('+1'),
                              ),
                              DropdownMenuItem(
                                value: '+44',
                                child: Text('+44'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _dialCode = v);
                              }
                            },
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          maxLength: 14,
                          decoration: InputDecoration(
                            hintText: s.t('enterPhone'),
                            counterText: '',
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (auth.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        auth.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),

                  const SizedBox(height: 22),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: auth.loading ? null : _sendOtp,
                      child: auth.loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(s.t('continue')),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Center(
                    child: Text(
                      'By continuing, you agree to our Terms & Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),

                  const SizedBox(height: 26),

                  const _LanguagePicker(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LanguageProvider>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.language, size: 17),
        const SizedBox(width: 8),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: p.locale,
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
            onChanged: (v) {
              if (v != null) p.setLanguage(v);
            },
          ),
        ),
      ],
    );
  }
}
