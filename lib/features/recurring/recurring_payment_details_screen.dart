
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../providers/recurring_payment.dart';
import '../../providers/recurring_payment_provider.dart';

class RecurringPaymentDetailsScreen extends StatefulWidget {
  final String paymentId;
  final RecurringPaymentService service;

  const RecurringPaymentDetailsScreen({
    super.key,
    required this.paymentId,
    required this.service,
  });

  @override
  State<RecurringPaymentDetailsScreen> createState() =>
      _RecurringPaymentDetailsScreenState();
}

class _RecurringPaymentDetailsScreenState
    extends State<RecurringPaymentDetailsScreen> {
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  String _money(int paise) => _currency.format(paise / 100);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RecurringPayment?>(
      stream: widget.service.watchPayment(widget.paymentId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Payment details')),
            body: Center(
              child: Text('Unable to load payment: ${snapshot.error}'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final payment = snapshot.data;

        if (payment == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Payment details')),
            body: const Center(
              child: Text('This payment is unavailable.'),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7F6),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF5F7F6),
            title: const Text(
              'Payment details',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenu(payment, value),
                itemBuilder: (_) => [
                  if (payment.isActive)
                    const PopupMenuItem(
                      value: 'pause',
                      child: Text('Pause schedule'),
                    ),
                  if (payment.isPaused)
                    const PopupMenuItem(
                      value: 'resume',
                      child: Text('Resume schedule'),
                    ),
                  const PopupMenuItem(
                    value: 'archive',
                    child: Text('Archive schedule'),
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _overviewCard(payment),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Schedule information',
                children: [
                  _detailRow('Category', payment.category),
                  _detailRow('Frequency', payment.frequencyLabel),
                  _detailRow(
                    'Expected amount',
                    _money(payment.amountPaise),
                  ),
                  _detailRow(
                    'Next due date',
                    _dateFormat.format(payment.nextDueDate),
                  ),
                  _detailRow(
                    'Status',
                    payment.scheduleStatus.toUpperCase(),
                  ),
                  _detailRow(
                    'Reminder preference',
                    '${payment.reminderDaysBefore} '
                        '${payment.reminderDaysBefore == 1 ? 'day' : 'days'} before',
                  ),
                  if (payment.notes?.isNotEmpty == true)
                    _detailRow('Notes', payment.notes!),
                ],
              ),
              const SizedBox(height: 16),
              if (payment.isActive && !payment.isCompleted)
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => _markPaid(payment),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF174C3C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text(
                      'Mark this cycle as paid',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              if (payment.isPaused)
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => _resume(payment),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Resume schedule'),
                  ),
                ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Payment history',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  StreamBuilder<List<PaymentOccurrence>>(
                    stream: widget.service.watchPaymentHistory(payment.id),
                    builder: (context, historySnapshot) {
                      final records = historySnapshot.data ?? [];
                      final total = records.fold<int>(
                        0,
                        (sum, record) => sum + record.actualAmountPaise,
                      );

                      return Text(
                        'Paid: ${_money(total)}',
                        style: const TextStyle(
                          color: Color(0xFF28765A),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _historyList(payment),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // OVERVIEW CARD
  // ------------------------------------------------------------

  Widget _overviewCard(RecurringPayment payment) {
    final days = payment.daysUntilDue();

    final Color color = payment.isCompleted
        ? Colors.blueGrey
        : payment.isPaused
            ? Colors.grey
            : days < 0
                ? Colors.red
                : days == 0
                    ? Colors.orange
                    : const Color(0xFF28765A);

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
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.event_repeat,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  payment.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'EXPECTED AMOUNT',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _money(payment.amountPaise),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.calendar_month,
                color: Colors.white70,
                size: 17,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Next due ${_dateFormat.format(payment.nextDueDate)}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  payment.getDueLabel(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // INFORMATION CARD
  // ------------------------------------------------------------

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE8ECE9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // PAYMENT HISTORY
  // ------------------------------------------------------------

  Widget _historyList(RecurringPayment payment) {
    return StreamBuilder<List<PaymentOccurrence>>(
      stream: widget.service.watchPaymentHistory(payment.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Unable to load payment history.');
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final records = snapshot.data ?? [];

        if (records.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE8ECE9)),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 34,
                    color: Colors.black38,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No payments recorded yet',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your completed payment cycles will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: records.map((record) {
            return InkWell(
              borderRadius: BorderRadius.circular(17),
              onTap: () => _showOccurrence(record),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: const Color(0xFFE8ECE9)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF28765A),
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormat('MMMM yyyy').format(record.dueDate),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          _money(record.actualAmountPaise),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Paid ${_dateFormat.format(record.paidAt)} · '
                            '${record.paymentMode}',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        if (record.receiptUrl != null)
                          const Icon(
                            Icons.attach_file,
                            size: 16,
                            color: Color(0xFF28765A),
                          ),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.black38,
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // MARK AS PAID
  // ------------------------------------------------------------

  Future<void> _markPaid(RecurringPayment payment) async {
    final amountController = TextEditingController(
      text: (payment.amountPaise / 100).toStringAsFixed(2),
    );
    final noteController = TextEditingController();
    final referenceController = TextEditingController();

    String mode = 'UPI';
    DateTime paidAt = DateTime.now();
    XFile? receipt;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickReceipt() async {
              final picker = ImagePicker();

              final selected = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
              );

              if (selected != null) {
                setSheetState(() => receipt = selected);
              }
            }

            Future<void> pickPaidDate() async {
              final selected = await showDatePicker(
                context: context,
                initialDate: paidAt,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(
                  const Duration(days: 1),
                ),
              );

              if (selected != null) {
                setSheetState(() => paidAt = selected);
              }
            }

            Future<void> submit() async {
              final amount = double.tryParse(
                amountController.text.trim(),
              );

              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a valid paid amount.'),
                  ),
                );
                return;
              }

              setSheetState(() => saving = true);

              try {
                await widget.service.markPaid(
                  paymentId: payment.id,
                  actualAmountPaise: (amount * 100).round(),
                  paidAt: paidAt,
                  paymentMode: mode,
                  note: noteController.text,
                  referenceId: referenceController.text,
                  receiptFile: receipt,
                );

                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext);
                }

                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Payment recorded successfully.'),
                    ),
                  );
                }
              } catch (e) {
                setSheetState(() => saving = false);

                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            }

            final bottom = MediaQuery.of(context).viewInsets.bottom;

            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                20 + bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(25),
                ),
              ),
              child: SingleChildScrollView(
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
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 17),
                    const Text(
                      'Record payment',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      payment.title,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Actual amount paid (₹)',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: mode,
                      decoration: const InputDecoration(
                        labelText: 'Payment mode',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        'UPI',
                        'Cash',
                        'Bank transfer',
                        'Card',
                        'Auto debit',
                        'Cheque',
                        'Other',
                      ].map((v) {
                        return DropdownMenuItem(
                          value: v,
                          child: Text(v),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setSheetState(() => mode = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: pickPaidDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        'Paid on ${_dateFormat.format(paidAt)}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: referenceController,
                      decoration: const InputDecoration(
                        labelText: 'Transaction / reference ID (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F8F6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.receipt_long_outlined,
                            color: Color(0xFF28765A),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              receipt == null
                                  ? 'Payment screenshot / receipt (optional)'
                                  : receipt!.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: pickReceipt,
                            child: Text(
                              receipt == null ? 'Attach' : 'Change',
                            ),
                          ),
                          if (receipt != null)
                            IconButton(
                              onPressed: () {
                                setSheetState(() => receipt = null);
                              },
                              icon: const Icon(Icons.close, size: 18),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: saving ? null : submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF174C3C),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Confirm payment'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // Let the bottom sheet finish its closing animation before
    // disposing the controllers used by its TextFields.
    await Future<void>.delayed(const Duration(milliseconds: 350));

    amountController.dispose();
    noteController.dispose();
    referenceController.dispose();
  }

  // ------------------------------------------------------------
  // PAYMENT RECORD DETAILS
  // ------------------------------------------------------------

  Future<void> _showOccurrence(PaymentOccurrence record) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment record',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                _detailRow(
                  'Scheduled date',
                  _dateFormat.format(record.dueDate),
                ),
                _detailRow(
                  'Paid on',
                  _dateFormat.format(record.paidAt),
                ),
                _detailRow(
                  'Scheduled amount',
                  _money(record.scheduledAmountPaise),
                ),
                _detailRow(
                  'Actual amount',
                  _money(record.actualAmountPaise),
                ),
                _detailRow('Payment mode', record.paymentMode),
                if (record.referenceId != null)
                  _detailRow('Reference ID', record.referenceId!),
                if (record.note != null)
                  _detailRow('Notes', record.note!),
                if (record.receiptUrl != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      record.receiptUrl!,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) {
                        return const Text(
                          'Receipt image could not be loaded.',
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check),
                    label: const Text('Close receipt'),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // PAUSE / RESUME / ARCHIVE
  // ------------------------------------------------------------

  Future<void> _resume(RecurringPayment payment) async {
    try {
      await widget.service.resumePayment(payment.id);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _handleMenu(
    RecurringPayment payment,
    String action,
  ) async {
    try {
      if (action == 'pause') {
        await widget.service.pauseSchedule(payment.id);
      } else if (action == 'resume') {
        await _resume(payment);
      } else if (action == 'archive') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Archive schedule?'),
              content: const Text(
                'This hides the schedule from the active list. '
                'Previous payment history will be preserved.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Archive'),
                ),
              ],
            );
          },
        );

        if (confirm == true) {
          await widget.service.archivePayment(payment.id);

          if (mounted) {
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}
