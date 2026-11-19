
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/account_provider.dart';
import '../../providers/expense.dart';
import '../../providers/expense_provider.dart';
import '../../providers/recurring_payment.dart';
import '../../providers/recurring_payment_provider.dart';
import '../expenses/expenses_screen.dart';
import '../recurring/recurring_payments_screen.dart';
import '../shared/account_details_screen.dart';
import '../shared/hisaab_logo.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  int _balance(Map<String, dynamic> data) =>
      (data['balancePaise'] as num?)?.toInt() ?? 0;

  String _money(int paise) => _currency.format(paise / 100);

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _monthStart => DateTime(
        DateTime.now().year,
        DateTime.now().month,
      );

  DateTime get _monthEnd => DateTime(
        DateTime.now().year,
        DateTime.now().month + 1,
      );

  bool _isToday(DateTime date) =>
      date.year == _today.year &&
      date.month == _today.month &&
      date.day == _today.day;

  bool _isThisMonth(DateTime date) =>
      !date.isBefore(_monthStart) && date.isBefore(_monthEnd);

  // Business: positive = payable, negative = receivable.
  // Personal: positive = receivable, negative = payable.
  _Totals _calculate(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> business,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> personal,
  ) {
    var receivable = 0;
    var payable = 0;

    for (final doc in business) {
      final value = _balance(doc.data());
      if (value < 0) receivable += value.abs();
      if (value > 0) payable += value;
    }

    for (final doc in personal) {
      final value = _balance(doc.data());
      if (value > 0) receivable += value;
      if (value < 0) payable += value.abs();
    }

    return _Totals(
      receivable: receivable,
      payable: payable,
      businessCount: business.length,
      personalCount: personal.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.read<AccountProvider>();
    final expenseProvider = ExpenseProvider();
    final recurringService = RecurringPaymentService();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: accountProvider.accounts('business'),
          builder: (context, businessSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: accountProvider.accounts('personal'),
              builder: (context, personalSnapshot) {
                final waiting =
                    businessSnapshot.connectionState ==
                            ConnectionState.waiting ||
                        personalSnapshot.connectionState ==
                            ConnectionState.waiting;

                if (businessSnapshot.hasError ||
                    personalSnapshot.hasError) {
                  return _errorState(
                    context,
                    businessSnapshot.error ?? personalSnapshot.error,
                  );
                }

                final business = businessSnapshot.data?.docs ?? [];
                final personal = personalSnapshot.data?.docs ?? [];
                final totals = _calculate(business, personal);

                return StreamBuilder<List<Expense>>(
                  stream: expenseProvider.watchExpenses(),
                  builder: (context, expenseSnapshot) {
                    return StreamBuilder<List<RecurringPayment>>(
                      stream: recurringService.watchPayments(),
                      builder: (context, recurringSnapshot) {
                        final expenses = expenseSnapshot.data ?? [];
                        final recurring = recurringSnapshot.data ?? [];

                        final expenseLoading =
                            expenseSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            !expenseSnapshot.hasData;

                        final recurringLoading =
                            recurringSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            !recurringSnapshot.hasData;

                        return RefreshIndicator(
                          color: AppTheme.green,
                          onRefresh: () async {
                            await Future<void>.delayed(
                              const Duration(milliseconds: 350),
                            );
                          },
                          child: CustomScrollView(
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  12,
                                  18,
                                  32,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildListDelegate([
                                    _header(context),
                                    const SizedBox(height: 27),

                                    _greeting(context),
                                    const SizedBox(height: 17),

                                    if (waiting ||
                                        expenseLoading ||
                                        recurringLoading)
                                      const LinearProgressIndicator(
                                        minHeight: 2,
                                        color: AppTheme.green,
                                      ),

                                    // ACCOUNT OVERVIEW
                                    _overviewCard(totals),
                                    const SizedBox(height: 14),
                                    _quickStats(totals),
                                    const SizedBox(height: 25),

                                    // EXPENSES
                                    _expenseOverview(
                                      context,
                                      expenses,
                                    ),
                                    const SizedBox(height: 22),

                                    // RECURRING PAYMENTS
                                    _recurringOverview(
                                      context,
                                      recurring,
                                    ),
                                    const SizedBox(height: 27),

                                    // BOOKS
                                    _sectionHeading(
                                      context,
                                      'Your books',
                                      '${totals.businessCount + totals.personalCount} total',
                                    ),
                                    const SizedBox(height: 12),

                                    _bookSummaryCard(
                                      context: context,
                                      title: 'Business Hisaab',
                                      subtitle:
                                          'Suppliers, dealers & customers',
                                      icon: Icons.storefront_rounded,
                                      color: AppTheme.green,
                                      accounts: business,
                                      isBusiness: true,
                                    ),
                                    const SizedBox(height: 11),

                                    _bookSummaryCard(
                                      context: context,
                                      title: 'Personal Hisaab',
                                      subtitle:
                                          'Friends, family & personal lending',
                                      icon: Icons.people_alt_rounded,
                                      color: const Color(0xFF7568B2),
                                      accounts: personal,
                                      isBusiness: false,
                                    ),
                                    const SizedBox(height: 25),

                                    // ACCOUNT BALANCES
                                    _sectionHeading(
                                      context,
                                      'Account balances',
                                      '${business.length + personal.length} accounts',
                                    ),
                                    const SizedBox(height: 12),

                                    if (business.isEmpty &&
                                        personal.isEmpty)
                                      _emptyAccounts(context)
                                    else ...[
                                      ..._accountRows(
                                        context,
                                        business,
                                        true,
                                      ),
                                      ..._accountRows(
                                        context,
                                        personal,
                                        false,
                                      ),
                                    ],

                                    const SizedBox(height: 15),
                                    _footnote(),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _header(BuildContext context) {
    return Row(
      children: [
        const HisaabLogo(size: 45),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hisaab',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.5,
                    ),
              ),
              const Text(
                'Your money, clearly organised',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 43,
          width: 43,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.line),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: AppTheme.muted,
          ),
        ),
      ],
    );
  }

  Widget _greeting(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting 👋',
          style: const TextStyle(
            color: AppTheme.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your financial overview',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -.7,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
          style: const TextStyle(
            color: AppTheme.muted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ACCOUNT OVERVIEW
  // ============================================================

  Widget _overviewCard(_Totals totals) {
    final net = totals.receivable - totals.payable;

    final netLabel = net > 0
        ? 'You are in a receivable position'
        : net < 0
            ? 'You have more payable than receivable'
            : 'Your books are currently balanced';

    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppTheme.green,
            AppTheme.greenDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: AppTheme.green.withValues(alpha: .19),
            blurRadius: 23,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'NET OUTSTANDING',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .76),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white70,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            _money(net.abs()),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            netLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .78),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 21),
          Container(height: 1, color: Colors.white24),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _overviewMetric(
                  label: 'TOTAL RECEIVABLE',
                  value: _money(totals.receivable),
                  icon: Icons.south_west_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 45,
                color: Colors.white24,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _overviewMetric(
                    label: 'TOTAL PAYABLE',
                    value: _money(totals.payable),
                    icon: Icons.north_east_rounded,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewMetric({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 14),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .72),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _quickStats(_Totals totals) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.storefront_outlined,
            label: 'Business',
            value: '${totals.businessCount}',
            tint: AppTheme.green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon: Icons.people_outline_rounded,
            label: 'Personal',
            value: '${totals.personalCount}',
            tint: const Color(0xFF7568B2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon: Icons.menu_book_rounded,
            label: 'Total books',
            value: '${totals.businessCount + totals.personalCount}',
            tint: const Color(0xFFB47A35),
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color tint,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 13, 9, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint, size: 19),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EXPENSE OVERVIEW
  // ============================================================

  Widget _expenseOverview(
    BuildContext context,
    List<Expense> expenses,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);

    final todayExpenses = expenses.where((e) {
      final date = e.createdAt;
      return date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
    }).toList();

    final monthExpenses = expenses.where((e) {
      return !e.createdAt.isBefore(monthStart) &&
          e.createdAt.isBefore(nextMonth);
    }).toList();

    final todayTotal = todayExpenses.fold<int>(
      0,
      (sum, e) => sum + e.amountPaise,
    );

    final monthTotal = monthExpenses.fold<int>(
      0,
      (sum, e) => sum + e.amountPaise,
    );

    final recent = [...expenses]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          context,
          'Expenses',
          'View all',
          onTap: () => _openExpenses(context),
        ),
        const SizedBox(height: 11),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: AppTheme.line),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3EE),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.payments_rounded,
                      color: Color(0xFF28765A),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Spent this month',
                          style: TextStyle(
                            color: AppTheme.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _money(monthTotal),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF174C3C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _roundAction(
                    icon: Icons.add_rounded,
                    onTap: () => _openExpenses(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: AppTheme.line),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: _smallMetric(
                      'Today',
                      _money(todayTotal),
                      Icons.today_outlined,
                    ),
                  ),
                  Expanded(
                    child: _smallMetric(
                      'Entries this month',
                      '${monthExpenses.length}',
                      Icons.receipt_long_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent expenses',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _openExpenses(context),
                child: const Text(
                  'See all',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ...recent.take(3).map((expense) {
            return _recentExpenseRow(expense);
          }),
        ],
      ],
    );
  }

  Widget _recentExpenseRow(Expense expense) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3EE),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: Color(0xFF28765A),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.note.trim().isEmpty
                      ? 'Expense'
                      : expense.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  DateFormat('dd MMM · hh:mm a')
                      .format(expense.createdAt),
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '- ${_money(expense.amountPaise)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECURRING PAYMENTS OVERVIEW
  // ============================================================

  Widget _recurringOverview(
    BuildContext context,
    List<RecurringPayment> payments,
  ) {
    final active = payments
        .where((p) => p.isActive && !p.isCompleted)
        .toList();

    final monthlyCommitment = active.fold<int>(
      0,
      (sum, p) => sum + p.monthlyEquivalentPaise,
    );

    final today = _today;

    final overdue = active.where((p) {
      final due = DateTime(
        p.nextDueDate.year,
        p.nextDueDate.month,
        p.nextDueDate.day,
      );
      return due.isBefore(today);
    }).length;

    final dueSoon = active.where((p) {
      final due = DateTime(
        p.nextDueDate.year,
        p.nextDueDate.month,
        p.nextDueDate.day,
      );
      final days = due.difference(today).inDays;
      return days >= 0 && days <= 7;
    }).length;

    final upcoming = [...active]
      ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          context,
          'Recurring payments',
          'Manage',
          onTap: () => _openRecurring(context),
        ),
        const SizedBox(height: 11),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: AppTheme.line),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF2E5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.event_repeat_rounded,
                      color: Color(0xFFB47730),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Monthly commitments',
                          style: TextStyle(
                            color: AppTheme.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _money(monthlyCommitment),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF9A6127),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _roundAction(
                    icon: Icons.add_rounded,
                    onTap: () => _openRecurring(context),
                    tint: const Color(0xFFB47730),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: AppTheme.line),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: _smallMetric(
                      'Active schedules',
                      '${active.length}',
                      Icons.repeat_rounded,
                    ),
                  ),
                  Expanded(
                    child: _smallMetric(
                      'Due in 7 days',
                      '$dueSoon',
                      Icons.calendar_month_outlined,
                    ),
                  ),
                  Expanded(
                    child: _smallMetric(
                      'Overdue',
                      '$overdue',
                      Icons.warning_amber_rounded,
                      valueColor: overdue > 0
                          ? Colors.red.shade700
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Upcoming schedules',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          ...upcoming.take(3).map((payment) {
            return _upcomingPaymentRow(
              context,
              payment,
            );
          }),
        ],
      ],
    );
  }

  Widget _upcomingPaymentRow(
    BuildContext context,
    RecurringPayment payment,
  ) {
    final due = DateTime(
      payment.nextDueDate.year,
      payment.nextDueDate.month,
      payment.nextDueDate.day,
    );

    final days = due.difference(_today).inDays;

    final Color statusColor = days < 0
        ? Colors.red.shade700
        : days == 0
            ? Colors.orange.shade800
            : const Color(0xFF28765A);

    final String dueLabel = days < 0
        ? '${days.abs()} days overdue'
        : days == 0
            ? 'Due today'
            : days == 1
                ? 'Due tomorrow'
                : 'Due in $days days';

    return InkWell(
      onTap: () => _openRecurring(context),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppTheme.line),
        ),
        child: Row(
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2E5),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.event_repeat_outlined,
                color: Color(0xFFB47730),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('dd MMM yyyy')
                        .format(payment.nextDueDate),
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _money(payment.amountPaise),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  dueLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SMALL SHARED WIDGETS
  // ============================================================

  Widget _smallMetric(
    String label,
    String value,
    IconData icon, {
    Color valueColor =  Colors.black87,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: AppTheme.muted,
          size: 16,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.muted,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _roundAction({
    required IconData icon,
    required VoidCallback onTap,
    Color tint = AppTheme.green,
  }) {
    return Material(
      color: tint.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(
          height: 38,
          width: 38,
          child: Icon(
            icon,
            color: tint,
            size: 21,
          ),
        ),
      ),
    );
  }

  void _openExpenses(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ExpensesScreen(),
      ),
    );
  }

  void _openRecurring(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RecurringPaymentsScreen(),
      ),
    );
  }

  // ============================================================
  // SECTION HEADINGS
  // ============================================================

  Widget _sectionHeading(
    BuildContext context,
    String title,
    String trailing, {
    VoidCallback? onTap,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        if (onTap != null)
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 4,
              ),
              child: Row(
                children: [
                  Text(
                    trailing,
                    style: const TextStyle(
                      color: AppTheme.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppTheme.green,
                  ),
                ],
              ),
            ),
          )
        else
          Text(
            trailing,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }

  // ============================================================
  // BUSINESS AND PERSONAL BOOKS
  // ============================================================

  Widget _bookSummaryCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> accounts,
    required bool isBusiness,
  }) {
    var receivable = 0;
    var payable = 0;

    for (final doc in accounts) {
      final value = _balance(doc.data());

      if (isBusiness) {
        if (value < 0) receivable += value.abs();
        if (value > 0) payable += value;
      } else {
        if (value > 0) receivable += value;
        if (value < 0) payable += value.abs();
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${accounts.length}',
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: AppTheme.line),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _bookAmount(
                  'Receivable',
                  receivable,
                  AppTheme.green,
                ),
              ),
              Expanded(
                child: _bookAmount(
                  'Payable',
                  payable,
                  Colors.red.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bookAmount(String label, int amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _money(amount),
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ACCOUNT BALANCE ROWS
  // ============================================================

  List<Widget> _accountRows(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    bool isBusiness,
  ) {
    return docs.map((doc) {
      final data = doc.data();
      final raw = _balance(data);

      final receivable = isBusiness ? raw < 0 : raw > 0;
      final payable = isBusiness ? raw > 0 : raw < 0;

      final amountColor = raw == 0
          ? AppTheme.muted
          : receivable
              ? AppTheme.green
              : Colors.red.shade600;

      final amountLabel = raw == 0
          ? 'Settled'
          : receivable
              ? 'Receivable'
              : payable
                  ? 'Payable'
                  : 'Balance';

      return Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          child: InkWell(
            borderRadius: BorderRadius.circular(17),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AccountDetailsScreen(
                    accountId: doc.id,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: AppTheme.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 41,
                    height: 41,
                    decoration: BoxDecoration(
                      color: (isBusiness
                              ? AppTheme.green
                              : const Color(0xFF7568B2))
                          .withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      isBusiness
                          ? Icons.storefront_outlined
                          : Icons.person_outline_rounded,
                      color: isBusiness
                          ? AppTheme.green
                          : const Color(0xFF7568B2),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['accountName']?.toString() ??
                              'Unnamed account',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${isBusiness ? 'Business' : 'Personal'} • $amountLabel',
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 10,
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
                        _money(raw.abs()),
                        style: TextStyle(
                          color: amountColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 17,
                        color: AppTheme.muted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  // ============================================================
  // EMPTY AND ERROR STATES
  // ============================================================

  Widget _emptyAccounts(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppTheme.line),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.menu_book_outlined,
            color: AppTheme.muted,
            size: 34,
          ),
          SizedBox(height: 10),
          Text(
            'No accounts yet',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4),
          Text(
            'Create a business or personal book to see your totals here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footnote() {
    return const Padding(
      padding: EdgeInsets.only(top: 5, bottom: 10),
      child: Text(
        'Account balances come from your ledgers. Expenses and recurring schedules are tracked separately.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppTheme.muted,
          fontSize: 10,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _errorState(BuildContext context, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 38,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load your dashboard',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              error?.toString() ?? 'Please try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Totals {
  final int receivable;
  final int payable;
  final int businessCount;
  final int personalCount;

  const _Totals({
    required this.receivable,
    required this.payable,
    required this.businessCount,
    required this.personalCount,
  });
}
