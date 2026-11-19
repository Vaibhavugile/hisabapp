
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/account_provider.dart';
import '../../providers/language_provider.dart';
import 'account_details_screen.dart';

class AccountListScreen extends StatefulWidget {
  final String type;
  final String title;
  final String subtitle;
  final String category;

  const AccountListScreen({
    super.key,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.category,
  });

  @override
  State<AccountListScreen> createState() =>
      _AccountListScreenState();
}

class _AccountListScreenState extends State<AccountListScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[HISAAB][ACCOUNT_LIST] $message');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please log in to view accounts.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: _showAddAccount,
            tooltip: 'Add account',
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              size: 27,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: strings.t('search'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? const Icon(Icons.tune)
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: context
                  .read<AccountProvider>()
                  .accounts(widget.type),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                        ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  _log('Account stream error: ${snapshot.error}');

                  return _errorView(snapshot.error.toString());
                }

                final query =
                    _searchController.text.trim().toLowerCase();

                final docs = (snapshot.data?.docs ?? [])
                    .where((doc) {
                  final data = doc.data();

                  final name = (data['accountName'] ?? '')
                      .toString()
                      .toLowerCase();

                  final phone = (data['phone'] ?? '')
                      .toString()
                      .toLowerCase();

                  final category = (data['category'] ?? '')
                      .toString()
                      .toLowerCase();

                  return name.contains(query) ||
                      phone.contains(query) ||
                      category.contains(query);
                }).toList();

                if (docs.isEmpty) {
                  return _empty(strings);
                }

                _log(
                  'Loaded ${docs.length} ${widget.type} accounts.',
                );

                return RefreshIndicator(
                  onRefresh: () async {
                    // Firestore snapshots refresh automatically.
                    // This allows the user to pull to refresh.
                    await Future<void>.delayed(
                      const Duration(milliseconds: 300),
                    );
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      110,
                    ),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();

                      return _accountCard(
                        context: context,
                        accountId: doc.id,
                        data: data,
                        userId: userId,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAccount,
        icon: const Icon(Icons.add),
        label: Text(strings.t('addAccount')),
      ),
    );
  }

  // ------------------------------------------------------------
  // ACCOUNT CARD
  // ------------------------------------------------------------

  Widget _accountCard({
    required BuildContext context,
    required String accountId,
    required Map<String, dynamic> data,
    required String userId,
  }) {
    final ownerId = data['ownerId']?.toString() ?? '';

    final isOwner = ownerId == userId;
    final isShared = data['isShared'] == true;

    final members = data['memberIds'];
    final isMember = members is List &&
        members.any((member) => member.toString() == userId);

    final isLinkedAccount = !isOwner && isMember;

    final ownerBalance =
        (data['balancePaise'] as num?)?.toInt() ?? 0;

    // Firestore balance is stored from the owner's perspective.
    final balance = isOwner || !isShared
        ? ownerBalance
        : -ownerBalance;

    final positiveMeansPayable =
        widget.type == 'business';

    final label = balance == 0
        ? 'Settled'
        : ((balance > 0) == positiveMeansPayable
            ? 'To pay'
            : 'To receive');

    final color = balance == 0
        ? AppTheme.muted
        : label == 'To pay'
            ? Colors.red
            : AppTheme.green;

    final accountName =
        data['accountName']?.toString() ?? 'Unnamed account';

    final category =
        data['category']?.toString() ?? '';

    final phone =
        data['phone']?.toString() ?? '';

    final sharingStatus =
        data['sharingStatus']?.toString() ?? '';

    final icon = widget.type == 'business'
        ? Icons.storefront_rounded
        : Icons.person_rounded;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          _log('Opening account: $accountId');

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AccountDetailsScreen(
                accountId: accountId,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor:
                    AppTheme.green.withValues(alpha: .10),
                child: Icon(
                  icon,
                  color: AppTheme.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      accountName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (category.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        _formatCategory(category),
                        style: Theme.of(context)
                            .textTheme.bodySmall,
                      ),
                    ],
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        phone,
                        style: Theme.of(context)
                            .textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 7),
                    _sharingIndicator(
                      isOwner: isOwner,
                      isShared: isShared,
                      isLinkedAccount: isLinkedAccount,
                      sharingStatus: sharingStatus,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹ ${(balance.abs() / 100).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: color,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right,
                color: AppTheme.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // SHARING STATUS
  // ------------------------------------------------------------

  Widget _sharingIndicator({
    required bool isOwner,
    required bool isShared,
    required bool isLinkedAccount,
    required String sharingStatus,
  }) {
    if (isLinkedAccount && isShared) {
      return _statusLabel(
        'Shared with you',
        Icons.people_alt_outlined,
        AppTheme.green,
      );
    }

    // Show the waiting state before the general shared state.
    // Otherwise every shared account owned by the current user would
    // display "Shared account", even before the invited person joins.
    if (isOwner &&
        isShared &&
        (sharingStatus == 'waiting_for_user' ||
            sharingStatus == 'invited')) {
      return _statusLabel(
        'Waiting for user to join',
        Icons.hourglass_empty_rounded,
        Colors.orange,
      );
    }

    if (isOwner && isShared) {
      return _statusLabel(
        'Shared account',
        Icons.people_alt_outlined,
        AppTheme.green,
      );
    }

    return _statusLabel(
      'Personal ledger',
      Icons.person_outline_rounded,
      AppTheme.muted,
    );
  }

  Widget _statusLabel(
    String text,
    IconData icon,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  String _formatCategory(String value) {
    if (value.isEmpty) return value;

    return value[0].toUpperCase() + value.substring(1);
  }

  // ------------------------------------------------------------
  // ERROR VIEW
  // ------------------------------------------------------------

  Widget _errorView(String error) {
    final isIndexError = error.contains('failed-precondition') ||
        error.toLowerCase().contains('index');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isIndexError
                  ? Icons.storage_rounded
                  : Icons.cloud_off_rounded,
              size: 46,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 14),
            Text(
              isIndexError
                  ? 'Firestore index required'
                  : 'Unable to load accounts',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (isIndexError)
              const Text(
                'Open Firebase Console > Firestore Database > Indexes and check the index status.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {});
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // EMPTY STATE
  // ------------------------------------------------------------

  Widget _empty(dynamic strings) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 48,
              color: AppTheme.muted.withValues(alpha: .6),
            ),
            const SizedBox(height: 14),
            Text(
              strings.t('noAccounts'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              strings.t('noAccountsHint'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _showAddAccount,
              icon: const Icon(Icons.add),
              label: Text(strings.t('addAccount')),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // ADD ACCOUNT SHEET
  // ------------------------------------------------------------

  Future<void> _showAddAccount() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddAccountSheet(
        type: widget.type,
        category: widget.category,
      ),
    );
  }
}

// ============================================================
// ADD ACCOUNT BOTTOM SHEET
// ============================================================

class _AddAccountSheet extends StatefulWidget {
  final String type;
  final String category;

  const _AddAccountSheet({
    required this.type,
    required this.category,
  });

  @override
  State<_AddAccountSheet> createState() =>
      _AddAccountSheetState();
}

class _AddAccountSheetState extends State<_AddAccountSheet> {
  final TextEditingController _name =
      TextEditingController();

  final TextEditingController _phone =
      TextEditingController();

  late String _category = widget.category;

  bool _isShared = false;
  bool _saving = false;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[HISAAB][ADD_ACCOUNT] $message');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;

    final categories = widget.type == 'business'
        ? [
            'supplier',
            'dealer',
            'distributor',
            'customer',
            'other',
          ]
        : [
            'friend',
            'family',
            'other',
          ];

    if (!categories.contains(_category)) {
      _category = categories.first;
    }

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * .88,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(26),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            22,
            14,
            22,
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.line,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                strings.t('addAccount'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Create a ledger and start recording transactions.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _name,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: strings.t('accountName'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: InputDecoration(
                  labelText: strings.t('category'),
                ),
                items: categories.map((value) {
                  return DropdownMenuItem(
                    value: value,
                    child: Text(
                      value[0].toUpperCase() +
                          value.substring(1),
                    ),
                  );
                }).toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _category = value);
                        }
                      },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _isShared
                      ? AppTheme.green.withValues(alpha: .07)
                      : Colors.grey.withValues(alpha: .05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isShared
                        ? AppTheme.green.withValues(alpha: .25)
                        : AppTheme.line,
                  ),
                ),
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isShared,
                  activeColor: AppTheme.green,
                  title: const Text(
                    'Share this account',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Let the other person view and manage this ledger after verifying their phone number.',
                    style: TextStyle(fontSize: 12, height: 1.35),
                  ),
                  onChanged: _saving
                      ? null
                      : (value) {
                          setState(() => _isShared = value);
                        },
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: InputDecoration(
                  labelText: _isShared
                      ? 'Other person mobile number *'
                      : 'Other person mobile number (optional)',
                  hintText: '10-digit mobile number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  prefixText: '+91 ',
                  helperText: _isShared
                      ? 'Access is granted only after they verify this exact number in Hisaab.'
                      : 'A number entered here will not grant access unless Share this account is enabled.',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppTheme.green.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.green.withValues(alpha: .18),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppTheme.green,
                      size: 19,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _isShared
                            ? 'You can use this ledger immediately. The other person can join later by verifying the mobile number above.'
                            : 'This ledger will remain private to your account. You can create a shared ledger by enabling Share this account.',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(strings.t('save')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;

    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter account name.'),
        ),
      );
      return;
    }

    final phone = _phone.text.trim();

    if (_isShared && phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the other person’s mobile number to share this account.'),
        ),
      );
      return;
    }

    if (phone.isNotEmpty &&
        !RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid 10-digit Indian mobile number.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    _log('Creating ${widget.type} account.');

    try {
      final accountId =
          await context.read<AccountProvider>().createAccount(
                name: _name.text.trim(),
                type: widget.type,
                category: _category,
                phone: phone,
                isShared: _isShared,
              );

      _log('Account created: $accountId');

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isShared
                ? 'Shared account created. The other person can join by verifying the invited phone number.'
                : 'Account created successfully.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      _log('Account creation failed: $error');

      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to create account: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
