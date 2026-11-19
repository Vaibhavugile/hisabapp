
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/ledger_transaction.dart';
import '../../providers/account_provider.dart';
import '../transactions/transaction_form_screen.dart';
import '../transactions/transaction_details_screen.dart';

class AccountDetailsScreen extends StatefulWidget {
  final String accountId;

  const AccountDetailsScreen({
    super.key,
    required this.accountId,
  });

  @override
  State<AccountDetailsScreen> createState() =>
      _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  String _filter = 'all';
  bool _processing = false;

  final List<Map<String, String>> _filters = const [
    {'key': 'all', 'label': 'All'},
    {'key': 'pending', 'label': 'Pending'},
    {'key': 'approved', 'label': 'Approved'},
    {'key': 'rejected', 'label': 'Rejected'},
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AccountProvider>();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: provider.account(widget.accountId),
      builder: (context, accountSnapshot) {
        if (accountSnapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!accountSnapshot.hasData ||
            !accountSnapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('Account not found')),
          );
        }

        final account = accountSnapshot.data!.data()!;
        final name =
            account['accountName']?.toString() ?? 'Account';
        final type =
            account['accountType']?.toString() ?? 'business';

        final ownerId = account['ownerId']?.toString() ?? '';
        final isOwner = ownerId == currentUid;
        final isShared = account['isShared'] == true;

        final rawBalance =
            (account['balancePaise'] as num?)?.toInt() ?? 0;

        final balance =
            isShared && !isOwner ? -rawBalance : rawBalance;

        final bills =
            (account['totalBillsPaise'] as num?)?.toInt() ?? 0;
        final payments =
            (account['totalPaymentsPaise'] as num?)?.toInt() ?? 0;

        final business = type == 'business';

        final balanceLabel = balance == 0
            ? 'Settled'
            : business
                ? (balance > 0
                    ? 'You have to pay'
                    : 'You will receive')
                : (balance > 0
                    ? 'You will receive'
                    : 'You have to pay');

        final balanceColor = balance == 0
            ? AppTheme.green
            : balance > 0
                ? (business ? Colors.red : AppTheme.green)
                : (business ? AppTheme.green : Colors.red);

        return Scaffold(
          appBar: AppBar(
            title: Text(name),
            actions: [
              if (isShared)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Center(
                    child: Icon(
                      Icons.people_alt_outlined,
                      color: AppTheme.green,
                    ),
                  ),
                ),
            ],
          ),
          body: StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: provider.transactions(widget.accountId),
            builder: (context, txSnapshot) {
              if (txSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Unable to load ledger: ${txSnapshot.error}',
                  ),
                );
              }

              final docs = txSnapshot.data?.docs ?? [];

              final allEntries = docs.map((doc) {
                return _LedgerEntry(
                  transaction: LedgerTransaction.fromMap(
                    doc.id,
                    doc.data(),
                  ),
                  data: doc.data(),
                );
              }).toList();

              final pendingCount = allEntries.where((entry) {
                return _status(entry.data) == 'pending';
              }).length;

              final filteredEntries = allEntries.where((entry) {
                if (_filter == 'all') return true;
                return _status(entry.data) == _filter;
              }).toList();

              return ListView(
                padding:
                    const EdgeInsets.fromLTRB(20, 8, 20, 110),
                children: [
                  _balanceCard(
                    balance: balance,
                    balanceLabel: balanceLabel,
                    balanceColor: balanceColor,
                    bills: bills,
                    payments: payments,
                  ),

                  const SizedBox(height: 22),

                  Text(
                    'Quick actions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  const SizedBox(height: 12),

                  if (business)
                    Row(
                      children: [
                        Expanded(
                          child: _action(
                            context,
                            'Add bill',
                            Icons.receipt_long,
                            AppTheme.green,
                            type,
                            name,
                            'bill',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _action(
                            context,
                            'Add payment',
                            Icons.payments_outlined,
                            Colors.red,
                            type,
                            name,
                            'payment',
                          ),
                        ),
                      ],
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _action(
                            context,
                            'Money given',
                            Icons.call_made,
                            AppTheme.green,
                            type,
                            name,
                            'money_lent',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _action(
                            context,
                            'Received back',
                            Icons.call_received,
                            Colors.blue,
                            type,
                            name,
                            'money_received',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _action(
                            context,
                            'Borrowed',
                            Icons.south_west,
                            Colors.orange,
                            type,
                            name,
                            'money_borrowed',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _action(
                            context,
                            'Repayment',
                            Icons.north_east,
                            Colors.purple,
                            type,
                            name,
                            'repayment_paid',
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (isShared && pendingCount > 0) ...[
                    const SizedBox(height: 20),
                    _pendingBanner(pendingCount),
                  ],

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transaction history',
                        style:
                            Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${filteredEntries.length} entries',
                        style:
                            Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _filterSelector(),

                  const SizedBox(height: 14),

                  if (txSnapshot.connectionState ==
                          ConnectionState.waiting &&
                      docs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (filteredEntries.isEmpty)
                    _emptyLedger(context)
                  else
                    ...filteredEntries.map((entry) {
                      return _transactionTile(
                        context,
                        entry,
                        business,
                        isOwner,
                        isShared,
                        currentUid,
                        name,
                      );
                    }),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _balanceCard({
    required int balance,
    required String balanceLabel,
    required Color balanceColor,
    required int bills,
    required int payments,
  }) {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.green, AppTheme.greenDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CURRENT BALANCE',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .75),
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹ ${(balance.abs() / 100).toStringAsFixed(2)}',
            style: TextStyle(
              color: balanceColor,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            balanceLabel,
            style: TextStyle(
              color: balanceColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _summary('Total entries', bills)),
              Container(
                width: 1,
                height: 38,
                color: Colors.white30,
              ),
              Expanded(
                child: _summary('Payments / returns', payments),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summary(String label, int paise) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .75),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '₹ ${(paise / 100).toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    String type,
    String name,
    String transactionType,
  ) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15),
        foregroundColor: color,
        side: BorderSide(
          color: color.withValues(alpha: .25),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionFormScreen(
              accountId: widget.accountId,
              accountType: type,
              accountName: name,
              initialType: transactionType,
            ),
          ),
        );
      },
      icon: Icon(icon),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _pendingBanner(int count) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.orange.withValues(alpha: .25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.pending_actions,
            color: Colors.orange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count transaction${count == 1 ? '' : 's'} waiting for the other member to confirm',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((filter) {
          final selected = _filter == filter['key'];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: selected,
              label: Text(filter['label']!),
              onSelected: (_) {
                setState(() => _filter = filter['key']!);
              },
              selectedColor:
                  AppTheme.green.withValues(alpha: .15),
              checkmarkColor: AppTheme.green,
              side: BorderSide(
                color: selected
                    ? AppTheme.green
                    : AppTheme.line,
              ),
              labelStyle: TextStyle(
                color: selected
                    ? AppTheme.green
                    : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _transactionTile(
    BuildContext context,
    _LedgerEntry item,
    bool business,
    bool isOwner,
    bool isShared,
    String currentUid,
    String accountName,
  ) {
    final entry = item.transaction;
    final data = item.data;

    final status = _status(data);
    final createdBy = data['createdBy']?.toString() ?? '';

    // Only the other member of a genuinely shared account may review
    // a pending entry. The creator must never approve or reject their own.
    final canReview = isShared &&
        status == 'pending' &&
        currentUid.isNotEmpty &&
        currentUid != createdBy;

    final ownerDelta = entry.ownerDeltaPaise;
    final effectiveDelta =
        isOwner ? ownerDelta : -ownerDelta;

    final positive = effectiveDelta >= 0;
    final amountColor =
        positive ? AppTheme.green : Colors.red;

    final title = switch (entry.type) {
      'bill' =>
        'Bill ${entry.billNumber?.isNotEmpty == true ? '#${entry.billNumber}' : ''}',
      'payment' => 'Payment made',
      'money_lent' => 'Money given',
      'money_received' => 'Money received back',
      'money_borrowed' => 'Money borrowed',
      'repayment_paid' => 'Repayment made',
      _ => entry.type,
    };

    final creatorName =
        data['createdByName']?.toString().trim() ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionDetailsScreen(
              accountName: accountName,
              transaction: data,
              isOwner: isOwner,
            ),
          ),
        );
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    amountColor.withValues(alpha: .09),
                child: Icon(
                  entry.type == 'bill'
                      ? Icons.receipt_long
                      : Icons.payments_outlined,
                  color: amountColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (entry.description.isNotEmpty)
                      Text(
                        entry.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.bodySmall,
                      ),
                    Text(
                      DateFormat('dd MMM yyyy')
                          .format(entry.transactionDate),
                      style:
                          Theme.of(context).textTheme.bodySmall,
                    ),
                    if (creatorName.isNotEmpty)
                      Text(
                        'Added by $creatorName',
                        style:
                            Theme.of(context).textTheme.bodySmall,
                      ),
                    if (entry.attachmentUrl != null)
                      const Text(
                        'Attachment included',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.green,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${positive ? '+' : '−'} ₹ ${(entry.amountPaise / 100).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _statusBadge(status),
                ],
              ),
            ],
          ),

          if (canReview) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _processing
                        ? null
                        : () => _rejectTransaction(entry.id),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _processing
                        ? null
                        : () => _approveTransaction(entry.id),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (status == 'rejected')
            _infoLine(
              'Rejected',
              data['rejectionReason']?.toString() ?? '',
              Colors.red,
            ),

          if (status == 'approved' &&
              data['approvedByName'] != null)
            _infoLine(
              'Confirmed by',
              data['approvedByName'].toString(),
              AppTheme.green,
            ),
        ],
      ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final Color color;
    final String label;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        label = 'Pending';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Rejected';
        break;
      default:
        color = AppTheme.green;
        label = 'Approved';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _infoLine(
    String label,
    String value,
    Color color,
  ) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$label: $value',
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveTransaction(
    String transactionId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Approve transaction?'),
        content: const Text(
          'This will confirm the transaction entered by the other person.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processing = true);

    try {
      await context
          .read<AccountProvider>()
          .approveLedgerTransaction(
        accountId: widget.accountId,
        transactionId: transactionId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction approved successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to approve: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _rejectTransaction(
    String transactionId,
  ) async {
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject transaction'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'Enter reason for rejection',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(
              dialogContext,
              reasonController.text.trim(),
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    reasonController.dispose();

    if (reason == null || !mounted) return;

    setState(() => _processing = true);

    try {
      await context
          .read<AccountProvider>()
          .rejectLedgerTransaction(
        accountId: widget.accountId,
        transactionId: transactionId,
        reason: reason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Transaction rejected and balance reversed',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to reject: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  String _status(Map<String, dynamic> data) {
    return data['status']?.toString() ?? 'approved';
  }

  Widget _emptyLedger(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 38,
            color: AppTheme.muted,
          ),
          const SizedBox(height: 10),
          const Text(
            'No transactions found',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            _filter == 'all'
                ? 'Add your first bill or payment to start this ledger.'
                : 'There are no ${_filter.toLowerCase()} transactions.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LedgerEntry {
  final LedgerTransaction transaction;
  final Map<String, dynamic> data;

  const _LedgerEntry({
    required this.transaction,
    required this.data,
  });
}
