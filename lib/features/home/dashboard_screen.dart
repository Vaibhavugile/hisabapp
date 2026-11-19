import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/account_provider.dart';
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

  // Business: positive balance means payable; negative means receivable.
  // Personal: positive balance means receivable; negative means payable.
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
    final provider = context.read<AccountProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: provider.accounts('business'),
          builder: (context, businessSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: provider.accounts('personal'),
              builder: (context, personalSnapshot) {
                final waiting =
                    businessSnapshot.connectionState == ConnectionState.waiting ||
                    personalSnapshot.connectionState == ConnectionState.waiting;

                if (businessSnapshot.hasError || personalSnapshot.hasError) {
                  return _errorState(
                    context,
                    businessSnapshot.error ?? personalSnapshot.error,
                  );
                }

                final business = businessSnapshot.data?.docs ?? [];
                final personal = personalSnapshot.data?.docs ?? [];
                final totals = _calculate(business, personal);

                return RefreshIndicator(
                  color: AppTheme.green,
                  onRefresh: () async {
                    await Future<void>.delayed(
                      const Duration(milliseconds: 350),
                    );
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate(
                            [
                              _header(context),
                              const SizedBox(height: 27),
                              Text(
                                'Good day 👋',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppTheme.muted),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your financial overview',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.5,
                                    ),
                              ),
                              const SizedBox(height: 18),
                              if (waiting)
                                const LinearProgressIndicator(
                                  minHeight: 2,
                                  color: AppTheme.green,
                                ),
                              _overviewCard(totals),
                              const SizedBox(height: 18),
                              _quickStats(totals),
                              const SizedBox(height: 27),
                              _sectionHeading(
                                context,
                                'Your books',
                                '${totals.businessCount + totals.personalCount} total',
                              ),
                              const SizedBox(height: 12),
                              _bookSummaryCard(
                                context: context,
                                title: 'Business Hisaab',
                                subtitle: 'Suppliers, dealers & customers',
                                icon: Icons.storefront_rounded,
                                color: AppTheme.green,
                                accounts: business,
                                isBusiness: true,
                              ),
                              const SizedBox(height: 12),
                              _bookSummaryCard(
                                context: context,
                                title: 'Personal Hisaab',
                                subtitle: 'Friends, family & personal lending',
                                icon: Icons.people_alt_rounded,
                                color: const Color(0xFF7568B2),
                                accounts: personal,
                                isBusiness: false,
                              ),
                              const SizedBox(height: 27),
                              _sectionHeading(
                                context,
                                'Account balances',
                                '${business.length + personal.length} accounts',
                              ),
                              const SizedBox(height: 12),
                              if (business.isEmpty && personal.isEmpty)
                                _emptyAccounts(context)
                              else ...[
                                ..._accountRows(context, business, true),
                                ..._accountRows(context, personal, false),
                              ],
                              const SizedBox(height: 12),
                              _footnote(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        const HisaabLogo(size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hisaab',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.4,
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
          width: 42,
          height: 42,
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
          colors: [AppTheme.green, AppTheme.greenDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: AppTheme.green.withValues(alpha: .20),
            blurRadius: 22,
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
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.25,
                  ),
                ),
              ),
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white70,
              ),
            ],
          ),
          const SizedBox(height: 8),
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
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 22),
          Container(height: 1, color: Colors.white24),
          const SizedBox(height: 17),
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
                height: 47,
                color: Colors.white24,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 17),
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
                  letterSpacing: .65,
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
              fontSize: 18,
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
            label: 'Business books',
            value: '${totals.businessCount}',
            tint: AppTheme.green,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: _statCard(
            icon: Icons.people_outline_rounded,
            label: 'Personal books',
            value: '${totals.personalCount}',
            tint: const Color(0xFF7568B2),
          ),
        ),
        const SizedBox(width: 11),
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
      padding: const EdgeInsets.fromLTRB(12, 14, 10, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint, size: 19),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
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
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(
    BuildContext context,
    String title,
    String trailing,
  ) {
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
                        fontSize: 11,
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
          const SizedBox(height: 15),
          Container(height: 1, color: AppTheme.line),
          const SizedBox(height: 13),
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
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _money(amount),
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

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
                  builder: (_) => AccountDetailsScreen(accountId: doc.id),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
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
                          data['accountName']?.toString() ?? 'Unnamed account',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
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
                          fontSize: 13,
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
            style: TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _footnote() {
    return const Padding(
      padding: EdgeInsets.only(top: 5, bottom: 10),
      child: Text(
        'Totals are calculated from your account balances. Tap any account to open its complete ledger.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppTheme.muted,
          fontSize: 10,
          height: 1.4,
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
            const Icon(Icons.cloud_off_outlined, size: 38, color: Colors.red),
            const SizedBox(height: 12),
            const Text(
              'Unable to load your dashboard',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              error?.toString() ?? 'Please try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
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
