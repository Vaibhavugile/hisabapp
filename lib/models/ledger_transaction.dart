
import 'package:cloud_firestore/cloud_firestore.dart';

class LedgerTransaction {
  final String id;
  final String accountId;
  final String type;

  // Amounts are stored in paise.
  final int amountPaise;
  final int ownerDeltaPaise;

  // Transaction information.
  final String description;
  final String paymentMode;
  final String? referenceNumber;
  final String? billNumber;
  final DateTime transactionDate;
  final DateTime? dueDate;

  // Attachment information.
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentType;

  // Contributor information.
  final String createdBy;
  final String createdByName;
  final String createdByRole;

  // Audit timestamps.
  final DateTime createdAt;
  final DateTime? updatedAt;

  const LedgerTransaction({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amountPaise,
    required this.ownerDeltaPaise,
    required this.description,
    required this.createdBy,
    this.createdByName = '',
    this.createdByRole = '',
    required this.paymentMode,
    this.referenceNumber,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentType,
    this.billNumber,
    required this.transactionDate,
    this.dueDate,
    required this.createdAt,
    this.updatedAt,
  });

  factory LedgerTransaction.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    DateTime readDate(
      dynamic value, {
      DateTime? fallback,
    }) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return fallback ?? DateTime.now();
    }

    DateTime? readNullableDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    final transactionDate = readDate(map['transactionDate']);

    return LedgerTransaction(
      id: id,
      accountId: map['accountId'] as String? ?? '',
      type: map['type'] as String? ?? '',
      amountPaise: (map['amountPaise'] as num?)?.toInt() ?? 0,
      ownerDeltaPaise:
          (map['ownerDeltaPaise'] as num?)?.toInt() ?? 0,

      description: map['description'] as String? ?? '',
      paymentMode: map['paymentMode'] as String? ?? 'cash',

      referenceNumber: map['referenceNumber'] as String?,
      billNumber: map['billNumber'] as String?,

      transactionDate: transactionDate,
      dueDate: readNullableDate(map['dueDate']),

      attachmentUrl: map['attachmentUrl'] as String?,
      attachmentName: map['attachmentName'] as String?,
      attachmentType: map['attachmentType'] as String?,

      createdBy: map['createdBy'] as String? ?? '',
      createdByName: map['createdByName'] as String? ?? '',
      createdByRole: map['createdByRole'] as String? ?? '',

      // Older transactions may not have createdAt.
      createdAt: readDate(
        map['createdAt'],
        fallback: transactionDate,
      ),

      updatedAt: readNullableDate(map['updatedAt']),
    );
  }

  // Convenient formatted amount in rupees.
  double get amountRupees => amountPaise / 100;

  // Whether this transaction has an uploaded attachment.
  bool get hasAttachment =>
      attachmentUrl != null && attachmentUrl!.isNotEmpty;

  // Human-readable transaction type.
  String get typeLabel {
    switch (type) {
      case 'bill':
        return 'Bill / Purchase';
      case 'payment':
        return 'Payment';
      case 'money_lent':
        return 'Money Given';
      case 'money_received':
        return 'Money Received';
      case 'money_borrowed':
        return 'Money Borrowed';
      case 'repayment_paid':
        return 'Repayment';
      default:
        return type;
    }
  }

  // Human-readable payment method.
  String get paymentModeLabel {
    switch (paymentMode) {
      case 'cash':
        return 'Cash';
      case 'upi':
        return 'UPI';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'cheque':
        return 'Cheque';
      case 'other':
        return 'Other';
      default:
        return paymentMode;
    }
  }
}
