
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class OtpScreen extends StatefulWidget {
  final String phone;

  const OtpScreen({
    super.key,
    required this.phone,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _code = TextEditingController();
  final FocusNode _otpFocus = FocusNode();

  static const Color _green = Color(0xFF087B50);
  static const Color _darkGreen = Color(0xFF064E38);
  static const Color _background = Color(0xFFF5F8F6);
  static const Color _border = Color(0xFFE5ECE7);

  @override
  void dispose() {
    _code.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  String get _maskedPhone {
    final phone = widget.phone;

    if (phone.length <= 5) return phone;

    return '${phone.substring(0, phone.length - 4)}'
        '••••';
  }

  Future<void> _verifyOtp() async {
    final code = _code.text.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enter the 6-digit OTP'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _darkGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
      return;
    }

    _otpFocus.unfocus();

    final success =
        await context.read<HisaabAuthProvider>().verifyOtp(code);

    if (!mounted) return;

    if (success) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<HisaabAuthProvider>();

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          // Emerald background
          Container(
            height: MediaQuery.of(context).size.height * 0.38,
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

          Positioned(
            top: -85,
            right: -75,
            child: _circle(
              220,
              Colors.white.withValues(alpha: 0.045),
            ),
          ),

          Positioned(
            top: 130,
            left: -80,
            child: _circle(
              160,
              Colors.white.withValues(alpha: 0.04),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top navigation
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.white.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(13),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(13),
                          onTap: () => Navigator.pop(context),
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      const Text(
                        'HISAAB',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 2,
                        ),
                      ),

                      const Spacer(),

                      const SizedBox(width: 44),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // Verification icon
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: Colors.white,
                    size: 37,
                  ),
                ),

                const SizedBox(height: 17),

                const Text(
                  'Secure Verification',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  'One final step to access your Hisaab',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 34),

                // Main OTP card
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(21, 0, 21, 25),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(
                        22, 27, 22, 25,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF123D2C)
                                .withValues(alpha: 0.09),
                            blurRadius: 35,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Small icon
                          Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF5EF),
                              borderRadius: BorderRadius.circular(17),
                            ),
                            child: const Icon(
                              Icons.sms_rounded,
                              color: _green,
                              size: 27,
                            ),
                          ),

                          const SizedBox(height: 21),

                          const Text(
                            'Verify your number',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF172B22),
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                            ),
                          ),

                          const SizedBox(height: 10),

                          Text(
                            'We sent a 6-digit verification code to',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 9),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F7F2),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.phone_iphone_rounded,
                                  color: _green,
                                  size: 16,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  _maskedPhone,
                                  style: const TextStyle(
                                    color: _darkGreen,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 31),

                          // OTP label
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'ENTER VERIFICATION CODE',
                              style: TextStyle(
                                color: Color(0xFF53645A),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.3,
                              ),
                            ),
                          ),

                          const SizedBox(height: 13),

                          // Six individual visual OTP boxes
                          GestureDetector(
                            onTap: () => _otpFocus.requestFocus(),
                            child: AnimatedBuilder(
                              animation: _code,
                              builder: (context, child) {
                                final value = _code.text;

                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: List.generate(6, (index) {
                                    final hasValue = index < value.length;
                                    final isCurrent =
                                        index == value.length &&
                                        value.length < 6;

                                    return AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 160,
                                      ),
                                      width: 43,
                                      height: 54,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isCurrent
                                            ? const Color(0xFFEAF5EF)
                                            : const Color(0xFFF8FAF8),
                                        borderRadius:
                                            BorderRadius.circular(13),
                                        border: Border.all(
                                          color: isCurrent
                                              ? _green
                                              : hasValue
                                                  ? const Color(0xFFB9D8C5)
                                                  : _border,
                                          width: isCurrent ? 1.6 : 1,
                                        ),
                                      ),
                                      child: Text(
                                        hasValue ? value[index] : '',
                                        style: const TextStyle(
                                          color: _darkGreen,
                                          fontSize: 21,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    );
                                  }),
                                );
                              },
                            ),
                          ),

                          // Actual input field (visually hidden)
                          SizedBox(
                            height: 1,
                            child: Opacity(
                              opacity: 0,
                              child: TextField(
                                controller: _code,
                                focusNode: _otpFocus,
                                enabled: !auth.loading,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                maxLength: 6,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                onSubmitted: (_) {
                                  if (_code.text.length == 6 &&
                                      !auth.loading) {
                                    _verifyOtp();
                                  }
                                },
                                decoration: const InputDecoration(
                                  counterText: '',
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          Text(
                            'Tap the boxes above to enter your OTP.',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),

                          // Error message
                          if (auth.error != null) ...[
                            const SizedBox(height: 17),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0F0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
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

                          const SizedBox(height: 25),

                          // Verify button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: FilledButton(
                              onPressed:
                                  auth.loading ? null : _verifyOtp,
                              style: FilledButton.styleFrom(
                                backgroundColor: _green,
                                disabledBackgroundColor:
                                    _green.withValues(alpha: 0.55),
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
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Verify & Continue',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 19,
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Security note
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.shield_rounded,
                                size: 16,
                                color: _green,
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  'Your verification is securely protected',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
