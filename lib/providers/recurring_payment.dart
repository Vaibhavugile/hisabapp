
import 'package:cloud_firestore/cloud_firestore.dart';

class RecurringPayment {
  final String id;
  final String title;
  final String category;

  /// Scheduled amount stored in paise.
  final int amountPaise;

  /// daily | weekly | every28Days | monthly | every2Months
  /// quarterly | halfYearly | yearly | custom
  final String frequency;

  /// Used only when frequency == custom.
  final int intervalValue;

  /// days | weeks | months | years
  final String intervalUnit;

  final DateTime nextDueDate;

  final bool isActive;
  final bool isCompleted;

  final int reminderDaysBefore;

  final String? notes;

  /// Whether marking this payment as paid should create an expense.
  final bool createExpenseOnPaid;

  /// Last successful payment date.
  final DateTime? lastPaidAt;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const RecurringPayment({
    required this.id,
    required this.title,
    required this.category,
    required this.amountPaise,
    required this.frequency,
    required this.nextDueDate,
    required this.isActive,
    this.isCompleted = false,
    this.intervalValue = 1,
    this.intervalUnit = 'months',
    this.reminderDaysBefore = 3,
    this.notes,
    this.createExpenseOnPaid = true,
    this.lastPaidAt,
    this.createdAt,
    this.updatedAt,
  });

  // ------------------------------------------------------------
  // FIRESTORE HELPERS
  // ------------------------------------------------------------

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) return null;

    final result = value.toString().trim();
    return result.isEmpty ? null : result;
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();

    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }

    return fallback;
  }

  factory RecurringPayment.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return RecurringPayment(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      category: (data['category'] ?? 'Other').toString(),
      amountPaise: _readInt(data['amountPaise']),
      frequency: (data['frequency'] ?? 'monthly').toString(),
      intervalValue: _readInt(
        data['intervalValue'],
        fallback: 1,
      ),
      intervalUnit: (data['intervalUnit'] ?? 'months').toString(),
      nextDueDate:
          _readDate(data['nextDueDate']) ?? DateTime.now(),
      isActive: data['isActive'] is bool
          ? data['isActive'] as bool
          : true,
      isCompleted: data['isCompleted'] == true,
      reminderDaysBefore: _readInt(
        data['reminderDaysBefore'],
        fallback: 3,
      ),
      notes: _readNullableString(data['notes']),
      createExpenseOnPaid:
          data['createExpenseOnPaid'] is bool
              ? data['createExpenseOnPaid'] as bool
              : true,
      lastPaidAt: _readDate(data['lastPaidAt']),
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'amountPaise': amountPaise,
      'frequency': frequency,
      'intervalValue': intervalValue,
      'intervalUnit': intervalUnit,
      'nextDueDate': Timestamp.fromDate(nextDueDate),
      'isActive': isActive,
      'isCompleted': isCompleted,
      'reminderDaysBefore': reminderDaysBefore,
      'notes': notes,
      'createExpenseOnPaid': createExpenseOnPaid,
      'lastPaidAt':
          lastPaidAt == null ? null : Timestamp.fromDate(lastPaidAt!),
      'createdAt':
          createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt':
          updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  // ------------------------------------------------------------
  // STATUS
  // ------------------------------------------------------------

  String get scheduleStatus {
    if (isCompleted) return 'completed';
    if (!isActive) return 'paused';
    return 'active';
  }

  bool get isPaused => !isActive && !isCompleted;

  bool get isRunning => isActive && !isCompleted;

  // ------------------------------------------------------------
  // FREQUENCY LABELS
  // ------------------------------------------------------------

  String get frequencyLabel {
    switch (frequency) {
      case 'daily':
        return 'Daily';

      case 'weekly':
        return 'Weekly';

      case 'every28Days':
        return 'Every 28 days';

      case 'monthly':
        return 'Monthly';

      case 'every2Months':
        return 'Every 2 months';

      case 'quarterly':
        return 'Every 3 months';

      case 'halfYearly':
        return 'Every 6 months';

      case 'yearly':
        return 'Yearly';

      case 'custom':
        return 'Every $intervalValue ${_unitLabel(intervalUnit, intervalValue)}';

      default:
        return frequency;
    }
  }

  static String _unitLabel(String unit, int value) {
    final singular = value == 1;

    switch (unit) {
      case 'days':
        return singular ? 'day' : 'days';
      case 'weeks':
        return singular ? 'week' : 'weeks';
      case 'months':
        return singular ? 'month' : 'months';
      case 'years':
        return singular ? 'year' : 'years';
      default:
        return unit;
    }
  }

  // ------------------------------------------------------------
  // MONTHLY EQUIVALENT
  // ------------------------------------------------------------

  int get monthlyEquivalentPaise {
    switch (frequency) {
      case 'daily':
        return amountPaise * 30;

      case 'weekly':
        return (amountPaise * 52 / 12).round();

      case 'every28Days':
        return (amountPaise * 365.25 / 28 / 12).round();

      case 'monthly':
        return amountPaise;

      case 'every2Months':
        return (amountPaise / 2).round();

      case 'quarterly':
        return (amountPaise / 3).round();

      case 'halfYearly':
        return (amountPaise / 6).round();

      case 'yearly':
        return (amountPaise / 12).round();

      case 'custom':
        switch (intervalUnit) {
          case 'days':
            if (intervalValue <= 0) return 0;
            return (amountPaise * 365.25 /
                    intervalValue /
                    12)
                .round();

          case 'weeks':
            if (intervalValue <= 0) return 0;
            return (amountPaise * 52 /
                    intervalValue /
                    12)
                .round();

          case 'months':
            if (intervalValue <= 0) return 0;
            return (amountPaise / intervalValue).round();

          case 'years':
            if (intervalValue <= 0) return 0;
            return (amountPaise / (intervalValue * 12)).round();

          default:
            return 0;
        }

      default:
        return 0;
    }
  }

  // ------------------------------------------------------------
  // DUE DATE HELPERS
  // ------------------------------------------------------------

  int daysUntilDue([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final due = DateTime(
      nextDueDate.year,
      nextDueDate.month,
      nextDueDate.day,
    );

    return due.difference(today).inDays;
  }

  bool isDueToday([DateTime? referenceDate]) {
    return daysUntilDue(referenceDate) == 0;
  }

  bool isOverdue([DateTime? referenceDate]) {
    return isActive &&
        !isCompleted &&
        daysUntilDue(referenceDate) < 0;
  }

  bool isDueWithin(
    int days, [
    DateTime? referenceDate,
  ]) {
    final remaining = daysUntilDue(referenceDate);

    return isActive &&
        !isCompleted &&
        remaining >= 0 &&
        remaining <= days;
  }

  String getDueLabel([DateTime? referenceDate]) {
    if (isCompleted) return 'Completed';
    if (!isActive) return 'Paused';

    final days = daysUntilDue(referenceDate);

    if (days < 0) {
      final count = days.abs();
      return 'Overdue by $count ${count == 1 ? 'day' : 'days'}';
    }

    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';

    return 'Due in $days days';
  }
}
