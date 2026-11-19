
import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final int amountPaise;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Expense({
    required this.id,
    required this.amountPaise,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  double get amount => amountPaise / 100;

  factory Expense.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return Expense(
      id: doc.id,
      amountPaise: (data['amountPaise'] as num?)?.toInt() ?? 0,
      note: data['note'] as String? ?? '',
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'amountPaise': amountPaise,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
