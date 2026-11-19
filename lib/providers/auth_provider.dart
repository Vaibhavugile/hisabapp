
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class HisaabAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-south1');

  bool _loading = false;
  String? _error;
  String? _pendingPhone;

  User? get user => _auth.currentUser;
  bool get loading => _loading;
  String? get error => _error;
  Stream<User?> get authState => _auth.authStateChanges();

  /// Sends OTP through MSG91 WhatsApp Authentication template.
  Future<void> sendOtp(String phone) async {
    _setLoading(true);
    _error = null;

    try {
      final normalizedPhone = phone.trim();

      if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(normalizedPhone)) {
        throw Exception(
          'Enter a valid phone number with country code.',
        );
      }

      final callable = _functions.httpsCallable('sendWhatsAppOtp');

      await callable.call({
        'phone': normalizedPhone,
      });

      _pendingPhone = normalizedPhone;
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Unable to send WhatsApp OTP.';
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _setLoading(false);
    }
  }

  /// Verifies OTP through backend and signs into Firebase using custom token.
  Future<bool> verifyOtp(String code) async {
    _setLoading(true);
    _error = null;

    try {
      if (_pendingPhone == null) {
        throw Exception('Please request a verification code first.');
      }

      if (!RegExp(r'^\d{6}$').hasMatch(code)) {
        throw Exception('Enter a valid 6-digit OTP.');
      }

      final callable = _functions.httpsCallable('verifyWhatsAppOtp');

      final result = await callable.call({
        'phone': _pendingPhone,
        'otp': code,
      });

      final data = Map<String, dynamic>.from(result.data as Map);

      final customToken = data['customToken'] as String?;

      if (customToken == null || customToken.isEmpty) {
        throw Exception('Verification succeeded but login token was missing.');
      }

      await _auth.signInWithCustomToken(customToken);

      _pendingPhone = null;
      return true;
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'OTP verification failed.';
      return false;
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? 'Firebase login failed.';
      return false;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _pendingPhone = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
