
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';

class AccountProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  // ------------------------------------------------------------
  // DEBUG LOGGING
  // ------------------------------------------------------------

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[HISAAB][ACCOUNT] $message');
    }
  }

  void _logError(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!kDebugMode) return;

    debugPrint('[HISAAB][ERROR][$operation] $error');

    if (error is FirebaseException) {
      debugPrint('Code: ${error.code}');
      debugPrint('Message: ${error.message}');

      if (error.code == 'failed-precondition') {
        debugPrint(
          '[HISAAB][INDEX] Firestore may require a composite index.',
        );
        debugPrint(
          'Check Firebase Console > Firestore Database > Indexes.',
        );
      }

      if (error.code == 'permission-denied') {
        debugPrint(
          '[HISAAB][SECURITY] Check Firestore security rules and membership.',
        );
      }

      if (error.code == 'unavailable') {
        debugPrint(
          '[HISAAB][NETWORK] Firestore service unavailable or network issue.',
        );
      }
    }

    debugPrintStack(stackTrace: stackTrace);
  }

  String _maskPhone(String phone) {
    if (phone.length < 5) return '***';
    return '${phone.substring(0, 3)}******${phone.substring(phone.length - 2)}';
  }

  // ------------------------------------------------------------
  // PHONE NUMBER NORMALIZATION
  // ------------------------------------------------------------

  /// Normalizes Indian phone numbers to +91XXXXXXXXXX.
  ///
  /// This method currently supports Indian mobile numbers.
  String normalizePhoneNumber(String phone) {
    var value = phone.trim();

    if (value.isEmpty) return '';

    value = value.replaceAll(RegExp(r'[\s\-()]'), '');

    if (value.startsWith('+91')) {
      value = value.substring(3);
    } else if (value.startsWith('0091')) {
      value = value.substring(4);
    } else if (value.startsWith('91') && value.length == 12) {
      value = value.substring(2);
    }

    value = value.replaceAll(RegExp(r'\D'), '');

    if (value.isEmpty) return '';

    if (value.length != 10 ||
        !RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
      throw ArgumentError(
        'Enter a valid 10-digit Indian mobile number.',
      );
    }

    return '+91$value';
  }

  // ------------------------------------------------------------
  // ACCOUNT STREAMS
  // ------------------------------------------------------------

  /// Fetches accounts where the logged-in user is a member.
  ///
  /// New account documents must contain memberIds.
  /// The account list screen should use the same query.
  Stream<QuerySnapshot<Map<String, dynamic>>> accounts(
    String type,
  ) {
    final userId = uid;

    if (userId == null) {
      _log('Account stream requested without login.');
      return const Stream.empty();
    }

    _log('Starting account stream. Type: $type');

    return _db
        .collection('accounts')
        .where('accountType', isEqualTo: type)
        .where('memberIds', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((Object error, StackTrace stackTrace) {
      _logError('accounts stream', error, stackTrace);
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> account(
    String accountId,
  ) {
    _log('Listening to account: $accountId');

    return _db
        .collection('accounts')
        .doc(accountId)
        .snapshots()
        .handleError((Object error, StackTrace stackTrace) {
      _logError('single account stream', error, stackTrace);
    });
  }

  /// Newest transactions first.
  Stream<QuerySnapshot<Map<String, dynamic>>> transactions(
    String accountId,
  ) {
    _log('Listening to transactions for: $accountId');

    return _db
        .collection('accounts')
        .doc(accountId)
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((Object error, StackTrace stackTrace) {
      _logError('transactions stream', error, stackTrace);
    });
  }

  // ------------------------------------------------------------
  // CREATE ACCOUNT
  // ------------------------------------------------------------

  Future<String> createAccount({
    required String name,
    required String type,
    required String category,
    String phone = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('Please log in first.');
    }

    if (name.trim().isEmpty) {
      throw ArgumentError('Account name is required.');
    }

    final normalizedPhone = normalizePhoneNumber(phone);

    final accountRef = _db.collection('accounts').doc();

    final ownerName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : 'Account owner';

    _log('Creating account. Type: $type');
    _log('Account ID: ${accountRef.id}');

    if (normalizedPhone.isNotEmpty) {
      _log(
        'Linked phone entered: ${_maskPhone(normalizedPhone)}',
      );
    }

    try {
      await accountRef.set({
        'ownerId': user.uid,
        'ownerName': ownerName,

        'accountName': name.trim(),
        'accountType': type,
        'category': category,

        // Original display phone and normalized matching phone.
        'phone': phone.trim(),
        'phoneNormalized': normalizedPhone,

        // Future automatic linking fields.
        'invitedPhone': normalizedPhone,
        'invitedPhoneNormalized': normalizedPhone,
        'linkedUserId': null,
        'linkedUserName': null,

        // Initially only the creator is a member.
        'memberIds': [user.uid],

        'isShared': false,
        'sharingStatus': normalizedPhone.isEmpty
            ? 'private'
            : 'waiting_for_user',

        'invitedAt': normalizedPhone.isEmpty
            ? null
            : FieldValue.serverTimestamp(),

        'joinedAt': null,

        'balancePaise': 0,
        'totalBillsPaise': 0,
        'totalPaymentsPaise': 0,

        'currency': 'INR',

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _log('Account created successfully: ${accountRef.id}');

      notifyListeners();

      return accountRef.id;
    } catch (error, stackTrace) {
      _logError('createAccount', error, stackTrace);
      rethrow;
    }
  }

  // ------------------------------------------------------------
  // MEMBERSHIP HELPERS
  // ------------------------------------------------------------

  bool _isAccountMember(
    Map<String, dynamic> data,
    String userId,
  ) {
    final ownerId = data['ownerId']?.toString() ?? '';
    final linkedUserId = data['linkedUserId']?.toString() ?? '';
    final members = data['memberIds'];

    final isMember = members is List &&
        members.any((member) => member.toString() == userId);

    return ownerId == userId ||
        linkedUserId == userId ||
        isMember;
  }

  /// Adds a member to an account.
  ///
  /// This is a helper for trusted account-linking workflows.
  /// Do not call it from an untrusted phone-number lookup.
  Future<void> addAccountMember({
    required String accountId,
    required String memberId,
    required String memberPhone,
    String memberName = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('Please log in first.');
    }

    if (memberId.trim().isEmpty) {
      throw ArgumentError('Member ID is required.');
    }

    final accountRef = _db.collection('accounts').doc(accountId);

    _log('Adding member to account: $accountId');

    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(accountRef);

        if (!snapshot.exists) {
          throw StateError('Account not found.');
        }

        final data = snapshot.data()!;

        if (data['ownerId'] != user.uid) {
          throw StateError(
            'Only the account owner can add a member.',
          );
        }

        final invitedPhone =
            data['invitedPhoneNormalized']?.toString() ?? '';

        final verifiedPhone = normalizePhoneNumber(memberPhone);

        if (invitedPhone.isEmpty ||
            invitedPhone != verifiedPhone) {
          throw StateError(
            'The verified phone number does not match the account.',
          );
        }

        final members = data['memberIds'] is List
            ? List<String>.from(
                (data['memberIds'] as List).map(
                  (item) => item.toString(),
                ),
              )
            : <String>[user.uid];

        if (members.contains(memberId)) {
          _log('Member already linked: $memberId');
          return;
        }

        members.add(memberId);

        transaction.update(accountRef, {
          'memberIds': members,
          'linkedUserId': memberId,
          'linkedUserName': memberName.trim().isEmpty
              ? null
              : memberName.trim(),
          'isShared': true,
          'sharingStatus': 'shared',
          'joinedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      _log('Member added successfully.');
      notifyListeners();
    } catch (error, stackTrace) {
      _logError('addAccountMember', error, stackTrace);
      rethrow;
    }
  }

  // ------------------------------------------------------------
  // TRANSACTION HELPERS
  // ------------------------------------------------------------

  bool _isBillType(String type) {
    return type == 'bill' ||
        type == 'money_lent' ||
        type == 'money_borrowed';
  }

  /// Adds a transaction.
  ///
  /// The amount affects the balance immediately.
  /// Shared transactions start as pending.
  /// Non-shared transactions are automatically approved.
  Future<void> addLedgerTransaction({
    required String accountId,
    required String type,
    required int amountPaise,
    required String description,
    required DateTime transactionDate,
    required String paymentMode,
    String? billNumber,
    String? referenceNumber,
    DateTime? dueDate,
    File? attachment,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('Please log in first.');
    }

    if (amountPaise <= 0) {
      throw ArgumentError(
        'Amount must be greater than zero.',
      );
    }

    final userId = user.uid;
    final accountRef = _db.collection('accounts').doc(accountId);

    final transactionRef = accountRef
        .collection('transactions')
        .doc(_uuid.v4());

    String? attachmentUrl;
    String? attachmentName;
    String? attachmentType;
    Reference? uploadedRef;

    _log('Adding transaction to account: $accountId');
    _log('Transaction type: $type');
    _log('Amount paise: $amountPaise');

    try {
      final initialAccount = await accountRef.get();

      if (!initialAccount.exists) {
        throw StateError('Account not found.');
      }

      final initialData = initialAccount.data()!;

      if (!_isAccountMember(initialData, userId)) {
        throw StateError(
          'You are not authorized to access this account.',
        );
      }

      // Upload attachment if selected.
      if (attachment != null) {
        attachmentName = attachment.uri.pathSegments.isNotEmpty
            ? attachment.uri.pathSegments.last
            : 'attachment';

        attachmentType =
            lookupMimeType(attachment.path) ??
                'application/octet-stream';

        final safeFileName = attachmentName.replaceAll(
          RegExp(r'[^a-zA-Z0-9._-]'),
          '_',
        );

        final storagePath =
            'hisaab/receipts/$accountId/${transactionRef.id}/$safeFileName';

        uploadedRef = _storage.ref().child(storagePath);

        _log('Uploading attachment: $safeFileName');

        await uploadedRef.putFile(
          attachment,
          SettableMetadata(contentType: attachmentType),
        );

        attachmentUrl = await uploadedRef.getDownloadURL();

        _log('Attachment uploaded successfully.');
      }

      final delta = _ownerDelta(type, amountPaise);

      await _db.runTransaction((transaction) async {
        final accountSnapshot = await transaction.get(accountRef);

        if (!accountSnapshot.exists) {
          throw StateError('Account not found.');
        }

        final accountData = accountSnapshot.data()!;

        if (!_isAccountMember(accountData, userId)) {
          throw StateError(
            'You are no longer authorized to add entries.',
          );
        }

        final ownerId =
            accountData['ownerId']?.toString() ?? '';

        final linkedUserId =
            accountData['linkedUserId']?.toString() ?? '';

        final members = accountData['memberIds'];

        final hasOtherMember =
            (linkedUserId.isNotEmpty && linkedUserId != userId) ||
                (members is List &&
                    members.any(
                      (member) => member.toString() != userId,
                    ));

        final isShared =
            accountData['isShared'] == true && hasOtherMember;

        final status = isShared ? 'pending' : 'approved';

        final oldBalance =
            (accountData['balancePaise'] as num?)?.toInt() ?? 0;

        final oldBills =
            (accountData['totalBillsPaise'] as num?)?.toInt() ?? 0;

        final oldPayments =
            (accountData['totalPaymentsPaise'] as num?)?.toInt() ?? 0;

        final isBill = _isBillType(type);
        final isPayment = !isBill;

        String contributorName =
            user.displayName?.trim() ?? '';

        final isOwner = ownerId == userId;

        if (contributorName.isEmpty) {
          contributorName = isOwner
              ? accountData['ownerName']?.toString().trim() ?? ''
              : accountData['linkedUserName']?.toString().trim() ?? '';
        }

        if (contributorName.isEmpty) {
          contributorName = user.phoneNumber?.trim() ?? '';
        }

        if (contributorName.isEmpty) {
          contributorName = user.email?.trim() ?? '';
        }

        if (contributorName.isEmpty) {
          contributorName = isOwner
              ? 'Account owner'
              : 'Linked user';
        }

        final contributorRole =
            isOwner ? 'owner' : 'linked_user';

        final serverTime = FieldValue.serverTimestamp();

        transaction.set(transactionRef, {
          'accountId': accountId,
          'type': type,
          'amountPaise': amountPaise,
          'ownerDeltaPaise': delta,
          'description': description.trim(),

          'billNumber': billNumber?.trim().isEmpty == true
              ? null
              : billNumber?.trim(),

          'referenceNumber':
              referenceNumber?.trim().isEmpty == true
                  ? null
                  : referenceNumber?.trim(),

          'paymentMode': paymentMode,
          'attachmentUrl': attachmentUrl,
          'attachmentName': attachmentName,
          'attachmentType': attachmentType,

          'transactionDate': Timestamp.fromDate(transactionDate),

          'dueDate': dueDate == null
              ? null
              : Timestamp.fromDate(dueDate),

          'createdBy': userId,
          'createdByName': contributorName,
          'createdByRole': contributorRole,

          'status': status,
          'approvedBy': null,
          'approvedByName': null,
          'approvedAt': null,
          'rejectedBy': null,
          'rejectedByName': null,
          'rejectedAt': null,
          'rejectionReason': null,

          'createdAt': serverTime,
          'updatedAt': serverTime,
        });

        transaction.update(accountRef, {
          'balancePaise': oldBalance + delta,
          'totalBillsPaise':
              oldBills + (isBill ? amountPaise : 0),
          'totalPaymentsPaise':
              oldPayments + (isPayment ? amountPaise : 0),
          'updatedAt': serverTime,
        });

        _log(
          'Transaction prepared. Status: $status. '
          'Balance: $oldBalance -> ${oldBalance + delta}',
        );
      });

      _log(
        'Transaction saved successfully: ${transactionRef.id}',
      );

      notifyListeners();
    } catch (error, stackTrace) {
      if (uploadedRef != null) {
        try {
          await uploadedRef.delete();
          _log('Removed uploaded attachment after failed transaction.');
        } catch (cleanupError, cleanupStack) {
          _logError(
            'attachment cleanup',
            cleanupError,
            cleanupStack,
          );
        }
      }

      _logError('addLedgerTransaction', error, stackTrace);
      rethrow;
    }
  }

  // ------------------------------------------------------------
  // APPROVE TRANSACTION
  // ------------------------------------------------------------

  Future<void> approveLedgerTransaction({
    required String accountId,
    required String transactionId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('Please log in first.');
    }

    final userId = user.uid;
    final accountRef = _db.collection('accounts').doc(accountId);

    final transactionRef = accountRef
        .collection('transactions')
        .doc(transactionId);

    _log('Approving transaction: $transactionId');

    try {
      await _db.runTransaction((transaction) async {
        final accountSnapshot = await transaction.get(accountRef);
        final transactionSnapshot =
            await transaction.get(transactionRef);

        if (!accountSnapshot.exists ||
            !transactionSnapshot.exists) {
          throw StateError(
            'Account or transaction not found.',
          );
        }

        final accountData = accountSnapshot.data()!;
        final entry = transactionSnapshot.data()!;

        if (!_isAccountMember(accountData, userId)) {
          throw StateError(
            'You are not authorized to approve this entry.',
          );
        }

        if (entry['createdBy'] == userId) {
          throw StateError(
            'You cannot approve your own entry.',
          );
        }

        if ((entry['status'] ?? 'approved') != 'pending') {
          throw StateError(
            'This entry is no longer pending.',
          );
        }

        final userName = _displayName(
          user,
          accountData,
          userId,
        );

        transaction.update(transactionRef, {
          'status': 'approved',
          'approvedBy': userId,
          'approvedByName': userName,
          'approvedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      _log('Transaction approved: $transactionId');
      notifyListeners();
    } catch (error, stackTrace) {
      _logError('approveLedgerTransaction', error, stackTrace);
      rethrow;
    }
  }

  // ------------------------------------------------------------
  // REJECT TRANSACTION
  // ------------------------------------------------------------

  Future<void> rejectLedgerTransaction({
    required String accountId,
    required String transactionId,
    String reason = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('Please log in first.');
    }

    final userId = user.uid;
    final accountRef = _db.collection('accounts').doc(accountId);

    final transactionRef = accountRef
        .collection('transactions')
        .doc(transactionId);

    _log('Rejecting transaction: $transactionId');

    try {
      await _db.runTransaction((transaction) async {
        final accountSnapshot = await transaction.get(accountRef);
        final transactionSnapshot =
            await transaction.get(transactionRef);

        if (!accountSnapshot.exists ||
            !transactionSnapshot.exists) {
          throw StateError(
            'Account or transaction not found.',
          );
        }

        final accountData = accountSnapshot.data()!;
        final entry = transactionSnapshot.data()!;

        if (!_isAccountMember(accountData, userId)) {
          throw StateError(
            'You are not authorized to reject this entry.',
          );
        }

        if (entry['createdBy'] == userId) {
          throw StateError(
            'You cannot reject your own entry.',
          );
        }

        if ((entry['status'] ?? 'approved') != 'pending') {
          throw StateError(
            'This entry is no longer pending.',
          );
        }

        final originalDelta =
            (entry['ownerDeltaPaise'] as num?)?.toInt() ?? 0;

        final amount =
            (entry['amountPaise'] as num?)?.toInt() ?? 0;

        final type = entry['type']?.toString() ?? '';
        final isBill = _isBillType(type);

        final oldBalance =
            (accountData['balancePaise'] as num?)?.toInt() ?? 0;

        final oldBills =
            (accountData['totalBillsPaise'] as num?)?.toInt() ?? 0;

        final oldPayments =
            (accountData['totalPaymentsPaise'] as num?)?.toInt() ?? 0;

        final userName = _displayName(
          user,
          accountData,
          userId,
        );

        final serverTime = FieldValue.serverTimestamp();

        transaction.update(transactionRef, {
          'status': 'rejected',
          'rejectedBy': userId,
          'rejectedByName': userName,
          'rejectedAt': serverTime,
          'rejectionReason': reason.trim(),
          'updatedAt': serverTime,
        });

        transaction.update(accountRef, {
          'balancePaise': oldBalance - originalDelta,
          'totalBillsPaise':
              oldBills - (isBill ? amount : 0),
          'totalPaymentsPaise':
              oldPayments - (isBill ? 0 : amount),
          'updatedAt': serverTime,
        });
      });

      _log('Transaction rejected and balance reversed.');
      notifyListeners();
    } catch (error, stackTrace) {
      _logError('rejectLedgerTransaction', error, stackTrace);
      rethrow;
    }
  }

  // ------------------------------------------------------------
  // DISPLAY NAME
  // ------------------------------------------------------------

  String _displayName(
    User user,
    Map<String, dynamic> accountData,
    String userId,
  ) {
    final name = user.displayName?.trim() ?? '';

    if (name.isNotEmpty) return name;

    if (accountData['ownerId'] == userId) {
      final ownerName =
          accountData['ownerName']?.toString().trim() ?? '';

      if (ownerName.isNotEmpty) return ownerName;
    } else {
      final linkedName =
          accountData['linkedUserName']?.toString().trim() ?? '';

      if (linkedName.isNotEmpty) return linkedName;
    }

    final phone = user.phoneNumber?.trim() ?? '';

    if (phone.isNotEmpty) return phone;

    final email = user.email?.trim() ?? '';

    if (email.isNotEmpty) return email;

    return 'Account member';
  }

  // ------------------------------------------------------------
  // OWNER BALANCE CALCULATION
  // ------------------------------------------------------------

  /// Calculates balance impact from the account owner's perspective.
  ///
  /// Positive:
  /// - Other person owes owner.
  /// - Owner owes supplier.
  ///
  /// Negative:
  /// - Owner has paid.
  /// - Owner has received money.
  int _ownerDelta(String type, int amount) {
    switch (type) {
      case 'bill':
      case 'money_lent':
        return amount;

      case 'payment':
      case 'money_received':
      case 'money_borrowed':
        return -amount;

      case 'repayment_paid':
        return amount;

      default:
        throw ArgumentError(
          'Unsupported transaction type: $type',
        );
    }
  }
}
