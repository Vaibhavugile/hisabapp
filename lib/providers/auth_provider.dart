import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class HisaabAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;
  bool _loading = false;
  String? _error;
  User? get user => _auth.currentUser;
  bool get loading => _loading;
  String? get error => _error;
  Stream<User?> get authState => _auth.authStateChanges();

  Future<void> sendOtp(String phone) async {
    _setLoading(true); _error = null;
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async { await _auth.signInWithCredential(credential); },
        verificationFailed: (e) { _error = e.message ?? 'Phone verification failed'; notifyListeners(); },
        codeSent: (id, _) { _verificationId = id; notifyListeners(); },
        codeAutoRetrievalTimeout: (id) { _verificationId = id; },
      );
    } on FirebaseAuthException catch (e) { _error = e.message ?? e.code; }
    finally { _setLoading(false); }
  }

  Future<bool> verifyOtp(String code) async {
    if (_verificationId == null) { _error = 'Please request a verification code first.'; notifyListeners(); return false; }
    _setLoading(true); _error = null;
    try {
      final credential = PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: code);
      await _auth.signInWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e) { _error = e.message ?? e.code; return false; }
    finally { _setLoading(false); }
  }

  Future<void> signOut() async => _auth.signOut();
  void clearError() { _error = null; notifyListeners(); }
  void _setLoading(bool value) { _loading = value; notifyListeners(); }
}
