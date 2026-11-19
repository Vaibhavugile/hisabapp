
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/recurring_payment.dart';
import '../../providers/recurring_payment_provider.dart';
import 'recurring_payment_details_screen.dart';

class RecurringPaymentsScreen extends StatefulWidget {
  const RecurringPaymentsScreen({super.key});

  @override
  State<RecurringPaymentsScreen> createState() =>
      _RecurringPaymentsScreenState();
}

class _RecurringPaymentsScreenState extends State<RecurringPaymentsScreen> {
  final RecurringPaymentService _service = RecurringPaymentService();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  String _statusFilter = 'all';

  String _money(int paise) => _currency.format(paise / 100);

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int _daysUntil(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.difference(_today()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        title: const Text(
          'Recurring payments',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: const Color(0xFFF5F7F6),
        actions: [
          IconButton(
            tooltip: 'Add recurring payment',
            onPressed: _addPayment,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Unique tag prevents collision with other FABs in navigation.
        heroTag: 'hisaab_recurring_payments_add_fab',
        onPressed: _addPayment,
        backgroundColor: const Color(0xFF174C3C),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add payment'),
      ),
      body: StreamBuilder<List<RecurringPayment>>(
        stream: _service.watchPayments(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _message(
              'Unable to load recurring payments.\n${snapshot.error}',
              Icons.cloud_off_outlined,
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data ?? [];
          final active =
              all.where((p) => p.isActive && !p.isCompleted).toList();

          final monthlyCommitment = active.fold<int>(
            0,
            (sum, payment) => sum + payment.monthlyEquivalentPaise,
          );

          final overdue =
              active.where((p) => _daysUntil(p.nextDueDate) < 0).length;

          final dueToday =
              active.where((p) => _daysUntil(p.nextDueDate) == 0).length;

          final upcoming = active.where((p) {
            final days = _daysUntil(p.nextDueDate);
            return days >= 0 && days <= 7;
          }).length;

          final filtered = all.where((payment) {
            switch (_statusFilter) {
              case 'active':
                return payment.isActive && !payment.isCompleted;
              case 'paused':
                return payment.isPaused;
              case 'completed':
                return payment.isCompleted;
              default:
                return true;
            }
          }).toList()
            ..sort((a, b) {
              if (a.isActive != b.isActive) {
                return a.isActive ? -1 : 1;
              }
              return a.nextDueDate.compareTo(b.nextDueDate);
            });

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              _summaryCard(
                monthlyCommitment: monthlyCommitment,
                activeCount: active.length,
                upcoming: upcoming,
                overdue: overdue,
                dueToday: dueToday,
              ),
              const SizedBox(height: 22),
              const Text(
                'Your payment schedules',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _statusSelector(),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                _emptyState()
              else
                ...filtered.map(_paymentCard),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // SUMMARY
  // ------------------------------------------------------------

  Widget _summaryCard({
    required int monthlyCommitment,
    required int activeCount,
    required int upcoming,
    required int overdue,
    required int dueToday,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF174C3C),
            Color(0xFF26765A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF174C3C).withOpacity(.15),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ESTIMATED MONTHLY COMMITMENT',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _money(monthlyCommitment),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Monthly equivalent of active schedules',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metric('$activeCount', 'Active schedules'),
              ),
              Expanded(
                child: _metric('$upcoming', 'Due in 7 days'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _statusMetric(
                Icons.warning_amber_rounded,
                '$overdue overdue',
                Colors.orangeAccent,
              ),
              _statusMetric(
                Icons.today_outlined,
                '$dueToday due today',
                Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _statusMetric(
    IconData icon,
    String label,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // FILTERS
  // ------------------------------------------------------------

  Widget _statusSelector() {
    const filters = {
      'all': 'All',
      'active': 'Active',
      'paused': 'Paused',
      'completed': 'Completed',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.entries.map((entry) {
          final selected = _statusFilter == entry.key;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: selected,
              onSelected: (_) {
                setState(() => _statusFilter = entry.key);
              },
              selectedColor: const Color(0xFFDCEDE4),
              labelStyle: TextStyle(
                color: selected
                    ? const Color(0xFF174C3C)
                    : Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ------------------------------------------------------------
  // PAYMENT CARD
  // ------------------------------------------------------------

  Widget _paymentCard(RecurringPayment payment) {
    final days = _daysUntil(payment.nextDueDate);

    final Color statusColor;

    if (payment.isCompleted) {
      statusColor = Colors.blueGrey;
    } else if (payment.isPaused) {
      statusColor = Colors.grey;
    } else if (days < 0) {
      statusColor = Colors.red;
    } else if (days == 0) {
      statusColor = Colors.orange;
    } else {
      statusColor = const Color(0xFF28765A);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 11),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: const BorderSide(color: Color(0xFFE8ECE9)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: () => _openDetails(payment),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(.09),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _categoryIcon(payment.category),
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          payment.category,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _money(payment.amountPaise),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 15,
                    color: statusColor,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      payment.getDueLabel(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    payment.frequencyLabel,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.event_outlined,
                    size: 13,
                    color: Colors.black45,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Next due: ${_dateFormat.format(payment.nextDueDate)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black54,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'View details',
                    style: TextStyle(
                      color: Color(0xFF28765A),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.chevron_right,
                    size: 17,
                    color: Color(0xFF28765A),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    final value = category.toLowerCase();

    if (value.contains('emi') || value.contains('loan')) {
      return Icons.account_balance_rounded;
    }

    if (value.contains('rent')) {
      return Icons.home_work_outlined;
    }

    if (value.contains('electric')) {
      return Icons.bolt_rounded;
    }

    if (value.contains('water')) {
      return Icons.water_drop_outlined;
    }

    if (value.contains('gas')) {
      return Icons.local_fire_department_outlined;
    }

    if (value.contains('mobile') || value.contains('recharge')) {
      return Icons.phone_android_rounded;
    }

    if (value.contains('salary')) {
      return Icons.payments_outlined;
    }

    if (value.contains('insurance')) {
      return Icons.shield_outlined;
    }

    if (value.contains('internet')) {
      return Icons.wifi_rounded;
    }

    if (value.contains('supplier')) {
      return Icons.local_shipping_outlined;
    }

    return Icons.event_repeat_rounded;
  }

  // ------------------------------------------------------------
  // OPEN DETAILS SCREEN
  // ------------------------------------------------------------

  void _openDetails(RecurringPayment payment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecurringPaymentDetailsScreen(
          paymentId: payment.id,
          service: _service,
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // ADD PAYMENT
  // ------------------------------------------------------------

  Future<void> _addPayment() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddRecurringPaymentSheet(
        service: _service,
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recurring payment created.'),
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // EMPTY STATE
  // ------------------------------------------------------------

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8ECE9)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.event_repeat_outlined,
            size: 42,
            color: Color(0xFF28765A),
          ),
          SizedBox(height: 12),
          Text(
            'No recurring payments found',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Add rent, EMIs, bills, subscriptions and other regular payments.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: Colors.black45),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ADD RECURRING PAYMENT SHEET
// ============================================================

class _AddRecurringPaymentSheet extends StatefulWidget {
  final RecurringPaymentService service;

  const _AddRecurringPaymentSheet({
    required this.service,
  });

  @override
  State<_AddRecurringPaymentSheet> createState() =>
      _AddRecurringPaymentSheetState();
}

class _AddRecurringPaymentSheetState
    extends State<_AddRecurringPaymentSheet> {
  final _formKey = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  final _interval = TextEditingController(text: '1');

  String _category = 'EMI';
  String _frequency = 'monthly';
  String _intervalUnit = 'months';

  int _reminderDays = 3;

  DateTime _dueDate = DateTime.now().add(
    const Duration(days: 1),
  );

  bool _createExpense = true;
  bool _saving = false;

  static const _categories = [
    'EMI',
    'Rent',
    'Electricity',
    'Water',
    'Gas',
    'Mobile recharge',
    'Internet',
    'Insurance',
    'Subscription',
    'Education fees',
    'Credit card',
    'Employee salary',
    'Supplier payment',
    'Maintenance',
    'Other',
  ];

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _notes.dispose();
    _interval.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(
        const Duration(days: 1),
      ),
      lastDate: DateTime.now().add(
        const Duration(days: 3650),
      ),
    );

    if (picked != null && mounted) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amount.text.trim());
    final interval = int.tryParse(_interval.text.trim()) ?? 1;

    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);

    try {
      await widget.service.createPayment(
        title: _title.text,
        category: _category,
        amountPaise: (amount * 100).round(),
        frequency: _frequency,
        firstDueDate: _dueDate,
        intervalValue: interval,
        intervalUnit: _intervalUnit,
        reminderDaysBefore: _reminderDays,
        notes: _notes.text,
        createExpenseOnPaid: _createExpense,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Add recurring payment',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Set it up once. Hisaab will track each payment cycle.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Payment name',
                  hintText: 'e.g. Home loan EMI',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Enter a payment name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Expected amount (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());

                  if (n == null || n <= 0) {
                    return 'Enter a valid amount';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((v) {
                  return DropdownMenuItem(
                    value: v,
                    child: Text(v),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _category = v);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _frequency,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Repeat frequency',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'daily',
                    child: Text('Daily'),
                  ),
                  DropdownMenuItem(
                    value: 'weekly',
                    child: Text('Weekly'),
                  ),
                  DropdownMenuItem(
                    value: 'every28Days',
                    child: Text('Every 28 days'),
                  ),
                  DropdownMenuItem(
                    value: 'monthly',
                    child: Text('Monthly'),
                  ),
                  DropdownMenuItem(
                    value: 'every2Months',
                    child: Text('Every 2 months'),
                  ),
                  DropdownMenuItem(
                    value: 'quarterly',
                    child: Text('Every 3 months'),
                  ),
                  DropdownMenuItem(
                    value: 'halfYearly',
                    child: Text('Every 6 months'),
                  ),
                  DropdownMenuItem(
                    value: 'yearly',
                    child: Text('Yearly'),
                  ),
                  DropdownMenuItem(
                    value: 'custom',
                    child: Text('Custom'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _frequency = v);
                  }
                },
              ),
              if (_frequency == 'custom') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _interval,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Repeat every',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (_frequency != 'custom') return null;

                          final n = int.tryParse((v ?? '').trim());

                          if (n == null || n <= 0) {
                            return 'Enter a valid interval';
                          }

                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _intervalUnit,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'days',
                            child: Text('Days'),
                          ),
                          DropdownMenuItem(
                            value: 'weeks',
                            child: Text('Weeks'),
                          ),
                          DropdownMenuItem(
                            value: 'months',
                            child: Text('Months'),
                          ),
                          DropdownMenuItem(
                            value: 'years',
                            child: Text('Years'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _intervalUnit = v);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  'First due date: '
                  '${DateFormat('dd MMM yyyy').format(_dueDate)}',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _reminderDays,
                decoration: const InputDecoration(
                  labelText: 'Reminder preference',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 0,
                    child: Text('On due date'),
                  ),
                  DropdownMenuItem(
                    value: 1,
                    child: Text('1 day before'),
                  ),
                  DropdownMenuItem(
                    value: 3,
                    child: Text('3 days before'),
                  ),
                  DropdownMenuItem(
                    value: 5,
                    child: Text('5 days before'),
                  ),
                  DropdownMenuItem(
                    value: 7,
                    child: Text('7 days before'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _reminderDays = v);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _createExpense,
                onChanged: (v) {
                  setState(() => _createExpense = v);
                },
                title: const Text(
                  'Create expense when paid',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Preference saved for the expense integration step.',
                  style: TextStyle(fontSize: 11),
                ),
                activeColor: const Color(0xFF28765A),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF174C3C),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 19,
                          width: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save payment schedule'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
