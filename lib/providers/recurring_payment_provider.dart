
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'recurring_payment.dart';

class RecurringPaymentService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  RecurringPaymentService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  // ------------------------------------------------------------
  // AUTHENTICATION
  // ------------------------------------------------------------

  String get _uid {
    final userId = _auth.currentUser?.uid;

    if (userId == null) {
      throw StateError('Please sign in to continue.');
    }

    return userId;
  }

  CollectionReference<Map<String, dynamic>> get _payments =>
      _db.collection('users').doc(_uid).collection('recurringPayments');

  // ------------------------------------------------------------
  // FREQUENCY VALIDATION
  // ------------------------------------------------------------

  static const List<String> supportedFrequencies = [
    'daily',
    'weekly',
    'every28Days',
    'monthly',
    'every2Months',
    'quarterly',
    'halfYearly',
    'yearly',
    'custom',
  ];

  static const List<String> supportedIntervalUnits = [
    'days',
    'weeks',
    'months',
    'years',
  ];

  void _validateFrequency({
    required String frequency,
    required int intervalValue,
    required String intervalUnit,
  }) {
    if (!supportedFrequencies.contains(frequency)) {
      throw ArgumentError('Invalid payment frequency.');
    }

    if (frequency == 'custom') {
      if (intervalValue <= 0 || intervalValue > 3650) {
        throw ArgumentError('Enter a valid custom interval.');
      }

      if (!supportedIntervalUnits.contains(intervalUnit)) {
        throw ArgumentError('Select a valid interval unit.');
      }
    }
  }

  // ------------------------------------------------------------
  // WATCH PAYMENT SCHEDULES
  // ------------------------------------------------------------

  Stream<List<RecurringPayment>> watchPayments() {
    return _payments.orderBy('nextDueDate').snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) => doc.data()['isArchived'] != true)
          .map(RecurringPayment.fromDoc)
          .toList(growable: false);
    });
  }

  // ------------------------------------------------------------
  // WATCH SINGLE PAYMENT
  // ------------------------------------------------------------

  Stream<RecurringPayment?> watchPayment(String paymentId) {
    return _payments.doc(paymentId).snapshots().map((doc) {
      if (!doc.exists || doc.data()?['isArchived'] == true) {
        return null;
      }

      return RecurringPayment.fromDoc(doc);
    });
  }

  // ------------------------------------------------------------
  // CREATE PAYMENT SCHEDULE
  // ------------------------------------------------------------

  Future<String> createPayment({
    required String title,
    required String category,
    required int amountPaise,
    required String frequency,
    required DateTime firstDueDate,
    int intervalValue = 1,
    String intervalUnit = 'months',
    int reminderDaysBefore = 3,
    String? notes,
    bool createExpenseOnPaid = true,
  }) async {
    final cleanTitle = title.trim();

    if (cleanTitle.isEmpty) {
      throw ArgumentError('Enter a payment name.');
    }

    if (amountPaise <= 0) {
      throw ArgumentError('Enter an amount greater than zero.');
    }

    if (reminderDaysBefore < 0 || reminderDaysBefore > 30) {
      throw ArgumentError('Reminder days must be between 0 and 30.');
    }

    _validateFrequency(
      frequency: frequency,
      intervalValue: intervalValue,
      intervalUnit: intervalUnit,
    );

    final dueDate = _dateOnly(firstDueDate);

    final doc = await _payments.add({
      'title': cleanTitle,
      'category': category.trim().isEmpty ? 'Other' : category.trim(),
      'amountPaise': amountPaise,
      'frequency': frequency,
      'intervalValue': intervalValue,
      'intervalUnit': intervalUnit,
      'nextDueDate': Timestamp.fromDate(dueDate),
      'isActive': true,
      'isCompleted': false,
      'isArchived': false,
      'reminderDaysBefore': reminderDaysBefore,
      'notes': _cleanNullable(notes),
      'createExpenseOnPaid': createExpenseOnPaid,
      'createdBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  // ------------------------------------------------------------
  // UPDATE PAYMENT SCHEDULE
  // ------------------------------------------------------------

  Future<void> updatePayment({
    required String paymentId,
    required String title,
    required String category,
    required int amountPaise,
    required String frequency,
    required DateTime nextDueDate,
    int intervalValue = 1,
    String intervalUnit = 'months',
    int reminderDaysBefore = 3,
    String? notes,
    bool createExpenseOnPaid = true,
  }) async {
    final cleanTitle = title.trim();

    if (cleanTitle.isEmpty) {
      throw ArgumentError('Enter a payment name.');
    }

    if (amountPaise <= 0) {
      throw ArgumentError('Enter an amount greater than zero.');
    }

    if (reminderDaysBefore < 0 || reminderDaysBefore > 30) {
      throw ArgumentError('Invalid reminder days.');
    }

    _validateFrequency(
      frequency: frequency,
      intervalValue: intervalValue,
      intervalUnit: intervalUnit,
    );

    final ref = _payments.doc(paymentId);
    final existing = await ref.get();

    if (!existing.exists || existing.data()?['isArchived'] == true) {
      throw StateError('This recurring payment does not exist.');
    }

    await ref.update({
      'title': cleanTitle,
      'category': category.trim().isEmpty ? 'Other' : category.trim(),
      'amountPaise': amountPaise,
      'frequency': frequency,
      'intervalValue': intervalValue,
      'intervalUnit': intervalUnit,
      'nextDueDate': Timestamp.fromDate(_dateOnly(nextDueDate)),
      'reminderDaysBefore': reminderDaysBefore,
      'notes': _cleanNullable(notes),
      'createExpenseOnPaid': createExpenseOnPaid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ------------------------------------------------------------
  // MARK PAYMENT AS PAID
  // ------------------------------------------------------------

  /// Receipt is optional.
  ///
  /// If supplied, the image is uploaded to Firebase Storage.
  /// The occurrence and next due date are then saved in Firestore.
  Future<void> markPaid({
    required String paymentId,
    required int actualAmountPaise,
    required DateTime paidAt,
    String paymentMode = 'Not specified',
    String? note,
    String? referenceId,
    XFile? receiptFile,
  }) async {
    if (actualAmountPaise <= 0) {
      throw ArgumentError('Paid amount must be greater than zero.');
    }

    if (paymentMode.trim().isEmpty) {
      throw ArgumentError('Select a payment mode.');
    }

    final paymentRef = _payments.doc(paymentId);

    // Read the schedule before uploading so we know the cycle ID.
    final initialSnapshot = await paymentRef.get();

    if (!initialSnapshot.exists) {
      throw StateError('This recurring payment no longer exists.');
    }

    final initialData = initialSnapshot.data()!;

    if (initialData['isArchived'] == true) {
      throw StateError('This payment schedule has been archived.');
    }

    if (initialData['isActive'] != true) {
      throw StateError('This payment schedule is inactive.');
    }

    final initialDueValue = initialData['nextDueDate'];

    if (initialDueValue is! Timestamp) {
      throw StateError('The next due date is missing.');
    }

    final dueDate = _dateOnly(initialDueValue.toDate());
    final occurrenceId = _occurrenceId(dueDate);

    final occurrenceRef =
        paymentRef.collection('occurrences').doc(occurrenceId);

    // Upload receipt outside the transaction.
    // Firestore may retry transaction callbacks, so uploads must not
    // happen inside the transaction.
    String? receiptUrl;
    String? receiptStoragePath;

    try {
      if (receiptFile != null) {
        final uploadResult = await _uploadReceipt(
          paymentId: paymentId,
          occurrenceId: occurrenceId,
          file: receiptFile,
        );

        receiptUrl = uploadResult.url;
        receiptStoragePath = uploadResult.storagePath;
      }

      await _db.runTransaction((transaction) async {
        final scheduleSnapshot = await transaction.get(paymentRef);
        final occurrenceSnapshot = await transaction.get(occurrenceRef);

        if (!scheduleSnapshot.exists) {
          throw StateError('This recurring payment no longer exists.');
        }

        final data = scheduleSnapshot.data()!;

        if (data['isArchived'] == true) {
          throw StateError('This payment schedule has been archived.');
        }

        if (data['isActive'] != true) {
          throw StateError('This payment schedule is inactive.');
        }

        final dueValue = data['nextDueDate'];

        if (dueValue is! Timestamp) {
          throw StateError('The next due date is missing.');
        }

        final currentDueDate = _dateOnly(dueValue.toDate());

        // Protect against another payment being recorded or the
        // schedule being edited while the receipt was uploading.
        if (_occurrenceId(currentDueDate) != occurrenceId) {
          throw StateError(
            'The schedule changed while recording payment. Please try again.',
          );
        }

        if (occurrenceSnapshot.exists) {
          throw StateError(
            'This payment cycle is already marked as paid.',
          );
        }

        final frequency =
            (data['frequency'] ?? 'monthly').toString();

        final intervalValue =
            (data['intervalValue'] as num?)?.toInt() ?? 1;

        final intervalUnit =
            (data['intervalUnit'] ?? 'months').toString();

        final createExpense =
            data['createExpenseOnPaid'] is bool
                ? data['createExpenseOnPaid'] as bool
                : true;

        final scheduledAmount =
            (data['amountPaise'] as num?)?.toInt() ?? 0;

        // Save the payment occurrence.
        transaction.set(occurrenceRef, {
          'paymentId': paymentId,
          'title': data['title'] ?? '',
          'category': data['category'] ?? 'Other',
          'dueDate': Timestamp.fromDate(currentDueDate),
          'paidAt': Timestamp.fromDate(paidAt),
          'scheduledAmountPaise': scheduledAmount,
          'actualAmountPaise': actualAmountPaise,
          'paymentMode': paymentMode.trim(),
          'referenceId': _cleanNullable(referenceId),
          'note': _cleanNullable(note),
          'receiptUrl': receiptUrl,
          'receiptStoragePath': receiptStoragePath,
          'status': 'paid',
          'createExpenseOnPaid': createExpense,

          // This is a marker until connected to the actual Expenses
          // provider. It does NOT mean an expense has been created.
          'expenseStatus':
              createExpense ? 'pending_integration' : 'disabled',

          'createdAt': FieldValue.serverTimestamp(),
        });

        final updateData = <String, dynamic>{
          'lastPaidAt': Timestamp.fromDate(paidAt),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Advance from the scheduled due date, never from paidAt.
        updateData['nextDueDate'] = Timestamp.fromDate(
          _nextDate(
            currentDueDate,
            frequency,
            intervalValue: intervalValue,
            intervalUnit: intervalUnit,
          ),
        );

        transaction.update(paymentRef, updateData);
      });
    } catch (_) {
      // If the transaction fails after upload, remove the orphaned file.
      if (receiptStoragePath != null) {
        try {
          await _storage.ref(receiptStoragePath).delete();
        } catch (_) {
          // Preserve the original payment error.
        }
      }

      rethrow;
    }
  }

  // ------------------------------------------------------------
  // OPTIONAL RECEIPT UPLOAD
  // ------------------------------------------------------------

  Future<_ReceiptUploadResult> _uploadReceipt({
    required String paymentId,
    required String occurrenceId,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw ArgumentError('The selected receipt file is empty.');
    }

    // Keep uploads reasonably sized.
    if (bytes.length > 10 * 1024 * 1024) {
      throw ArgumentError('Receipt image must be 10 MB or smaller.');
    }

    final extension = _fileExtension(file.name);
    final contentType = _contentType(extension);

    if (contentType == null) {
      throw ArgumentError('Select a JPG, PNG or WebP image.');
    }

    final storagePath =
        'users/$_uid/recurringPayments/$paymentId/receipts/'
        '${occurrenceId}_${DateTime.now().millisecondsSinceEpoch}.$extension';

    final storageRef = _storage.ref(storagePath);

    final metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: {
        'paymentId': paymentId,
        'occurrenceId': occurrenceId,
        'uploadedBy': _uid,
      },
    );

    final snapshot = await storageRef.putData(
      bytes,
      metadata,
    );

    final downloadUrl = await snapshot.ref.getDownloadURL();

    return _ReceiptUploadResult(
      url: downloadUrl,
      storagePath: storagePath,
    );
  }

  String _fileExtension(String fileName) {
    final index = fileName.lastIndexOf('.');

    if (index == -1) return '';

    return fileName.substring(index + 1).toLowerCase();
  }

  String? _contentType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';

      case 'png':
        return 'image/png';

      case 'webp':
        return 'image/webp';

      default:
        return null;
    }
  }

  // ------------------------------------------------------------
  // PAYMENT HISTORY
  // ------------------------------------------------------------

  Stream<List<PaymentOccurrence>> watchPaymentHistory(
    String paymentId,
  ) {
    return _payments
        .doc(paymentId)
        .collection('occurrences')
        .orderBy('paidAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(PaymentOccurrence.fromDoc)
          .toList(growable: false);
    });
  }

  // ------------------------------------------------------------
  // SINGLE PAYMENT HISTORY RECORD
  // ------------------------------------------------------------

  Future<PaymentOccurrence?> getPaymentOccurrence({
    required String paymentId,
    required String occurrenceId,
  }) async {
    final doc = await _payments
        .doc(paymentId)
        .collection('occurrences')
        .doc(occurrenceId)
        .get();

    if (!doc.exists) return null;

    return PaymentOccurrence.fromDoc(doc);
  }

  // ------------------------------------------------------------
  // PAUSE / RESUME
  // ------------------------------------------------------------

  Future<void> pausePayment(
    String paymentId,
    bool isActive,
  ) async {
    final ref = _payments.doc(paymentId);
    final snapshot = await ref.get();

    if (!snapshot.exists) {
      throw StateError('Payment schedule not found.');
    }

    final data = snapshot.data()!;

    if (data['isArchived'] == true) {
      throw StateError('This payment has been archived.');
    }

    if (data['isCompleted'] == true && isActive) {
      throw StateError('A completed payment cannot be resumed.');
    }

    await ref.update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resumePayment(String paymentId) {
    return pausePayment(paymentId, true);
  }

  Future<void> pauseSchedule(String paymentId) {
    return pausePayment(paymentId, false);
  }

  // ------------------------------------------------------------
  // ARCHIVE SCHEDULE
  // Keeps previous payment history.
  // ------------------------------------------------------------

  Future<void> deletePayment(String paymentId) async {
    final ref = _payments.doc(paymentId);
    final snapshot = await ref.get();

    if (!snapshot.exists) {
      throw StateError('Payment schedule not found.');
    }

    await ref.update({
      'isActive': false,
      'isArchived': true,
      'archivedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> archivePayment(String paymentId) {
    return deletePayment(paymentId);
  }

  // ------------------------------------------------------------
  // RESTORE ARCHIVED SCHEDULE
  // ------------------------------------------------------------

  Future<void> restorePayment(String paymentId) async {
    final ref = _payments.doc(paymentId);
    final snapshot = await ref.get();

    if (!snapshot.exists) {
      throw StateError('Payment schedule not found.');
    }

    final data = snapshot.data()!;

    if (data['isCompleted'] == true) {
      throw StateError('A completed schedule cannot be restored.');
    }

    await ref.update({
      'isArchived': false,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ------------------------------------------------------------
  // DATE CALCULATIONS
  // ------------------------------------------------------------

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _occurrenceId(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _nextDate(
    DateTime current,
    String frequency, {
    int intervalValue = 1,
    String intervalUnit = 'months',
  }) {
    switch (frequency) {
      case 'daily':
        return current.add(const Duration(days: 1));

      case 'weekly':
        return current.add(const Duration(days: 7));

      case 'every28Days':
        return current.add(const Duration(days: 28));

      case 'monthly':
        return _addMonths(current, 1);

      case 'every2Months':
        return _addMonths(current, 2);

      case 'quarterly':
        return _addMonths(current, 3);

      case 'halfYearly':
        return _addMonths(current, 6);

      case 'yearly':
        return _addMonths(current, 12);

      case 'custom':
        if (intervalValue <= 0) {
          throw ArgumentError('Invalid custom interval.');
        }

        switch (intervalUnit) {
          case 'days':
            return current.add(Duration(days: intervalValue));

          case 'weeks':
            return current.add(Duration(days: intervalValue * 7));

          case 'months':
            return _addMonths(current, intervalValue);

          case 'years':
            return _addMonths(current, intervalValue * 12);

          default:
            throw ArgumentError('Invalid custom interval unit.');
        }

      default:
        throw ArgumentError('Unsupported payment frequency.');
    }
  }

  /// Adds calendar months while clamping dates such as 31 January
  /// to the last valid day in the target month.
  DateTime _addMonths(DateTime date, int months) {
    final monthIndex = date.month - 1 + months;

    final year = date.year + (monthIndex ~/ 12);
    final month = (monthIndex % 12) + 1;

    final lastDay = DateTime(year, month + 1, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;

    return DateTime(year, month, day);
  }

  String? _cleanNullable(String? value) {
    if (value == null) return null;

    final clean = value.trim();

    return clean.isEmpty ? null : clean;
  }
}

// ============================================================
// RECEIPT UPLOAD RESULT
// ============================================================

class _ReceiptUploadResult {
  final String url;
  final String storagePath;

  const _ReceiptUploadResult({
    required this.url,
    required this.storagePath,
  });
}

// ============================================================
// PAYMENT OCCURRENCE MODEL
// ============================================================

class PaymentOccurrence {
  final String id;
  final String paymentId;
  final String title;

  final DateTime dueDate;
  final DateTime paidAt;

  final int scheduledAmountPaise;
  final int actualAmountPaise;

  final String paymentMode;
  final String status;

  final String? note;
  final String? referenceId;

  final String? receiptUrl;
  final String? receiptStoragePath;

  final String expenseStatus;

  const PaymentOccurrence({
    required this.id,
    required this.paymentId,
    required this.title,
    required this.dueDate,
    required this.paidAt,
    required this.scheduledAmountPaise,
    required this.actualAmountPaise,
    required this.paymentMode,
    required this.status,
    required this.expenseStatus,
    this.note,
    this.referenceId,
    this.receiptUrl,
    this.receiptStoragePath,
  });

  factory PaymentOccurrence.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    DateTime readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    int readInt(dynamic value) {
      if (value is num) return value.toInt();
      return 0;
    }

    String? readNullableString(dynamic value) {
      if (value == null) return null;

      final result = value.toString().trim();
      return result.isEmpty ? null : result;
    }

    return PaymentOccurrence(
      id: doc.id,
      paymentId: (data['paymentId'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      dueDate: readDate(data['dueDate']),
      paidAt: readDate(data['paidAt']),
      scheduledAmountPaise: readInt(data['scheduledAmountPaise']),
      actualAmountPaise: readInt(data['actualAmountPaise']),
      paymentMode: (data['paymentMode'] ?? 'Not specified').toString(),
      status: (data['status'] ?? 'paid').toString(),
      expenseStatus:
          (data['expenseStatus'] ?? 'not_recorded').toString(),
      note: readNullableString(data['note']),
      referenceId: readNullableString(data['referenceId']),
      receiptUrl: readNullableString(data['receiptUrl']),
      receiptStoragePath:
          readNullableString(data['receiptStoragePath']),
    );
  }
}
