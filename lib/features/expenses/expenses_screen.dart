
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/expense.dart';
import '../../providers/expense_provider.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ExpenseProvider _provider = ExpenseProvider();
  final TextEditingController _searchController = TextEditingController();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final DateFormat _dayFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');

  String _dateFilter = 'month';
  String _sortOrder = 'newest';
  String _search = '';

  DateTime? _customStart;
  DateTime? _customEnd;

  String _money(int paise) => _currency.format(paise / 100);

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _startOfWeek(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day - (date.weekday - 1),
    );
  }

  DateTime _startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  DateTime _endOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // DATE FILTERING
  // ------------------------------------------------------------

  bool _matchesDate(Expense expense) {
    final date = expense.createdAt;

    switch (_dateFilter) {
      case 'today':
        return date.year == _today.year &&
            date.month == _today.month &&
            date.day == _today.day;

      case 'yesterday':
        final yesterday = _today.subtract(const Duration(days: 1));
        return date.year == yesterday.year &&
            date.month == yesterday.month &&
            date.day == yesterday.day;

      case 'week':
        return !date.isBefore(_startOfWeek(_today)) &&
            !date.isAfter(DateTime.now());

      case 'month':
        return !date.isBefore(_startOfMonth(_today)) &&
            !date.isAfter(_endOfMonth(_today));

      case 'custom':
        if (_customStart == null || _customEnd == null) return true;

        final start = DateTime(
          _customStart!.year,
          _customStart!.month,
          _customStart!.day,
        );

        final end = DateTime(
          _customEnd!.year,
          _customEnd!.month,
          _customEnd!.day,
          23,
          59,
          59,
          999,
        );

        return !date.isBefore(start) && !date.isAfter(end);

      default:
        return true;
    }
  }

  List<Expense> _filterExpenses(List<Expense> expenses) {
    final result = expenses.where((expense) {
      final matchesDate = _matchesDate(expense);

      final matchesSearch = _search.isEmpty ||
          expense.note.toLowerCase().contains(_search.toLowerCase()) ||
          _money(expense.amountPaise).contains(_search);

      return matchesDate && matchesSearch;
    }).toList();

    switch (_sortOrder) {
      case 'oldest':
        result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'highest':
        result.sort((a, b) => b.amountPaise.compareTo(a.amountPaise));
        break;
      case 'lowest':
        result.sort((a, b) => a.amountPaise.compareTo(b.amountPaise));
        break;
      default:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return result;
  }

  // ------------------------------------------------------------
  // CUSTOM DATE RANGE
  // ------------------------------------------------------------

  Future<void> _selectCustomRange() async {
    final initialStart = _customStart ?? _startOfMonth(_today);
    final initialEnd = _customEnd ?? _today;

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: initialStart.isAfter(DateTime.now())
            ? _today
            : initialStart,
        end: initialEnd.isAfter(DateTime.now()) ? _today : initialEnd,
      ),
      helpText: 'SELECT EXPENSE DATE RANGE',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF174C3C),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (range != null && mounted) {
      setState(() {
        _customStart = range.start;
        _customEnd = range.end;
        _dateFilter = 'custom';
      });
    }
  }

  // ------------------------------------------------------------
  // MAIN SCREEN
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7F6),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expenses',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Track where your money goes',
              style: TextStyle(
                fontSize: 10,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add expense',
            onPressed: () => _openExpenseForm(),
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              size: 26,
            ),
          ),
          const SizedBox(width: 5),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'hisaab_expenses_add_fab',
        onPressed: () => _openExpenseForm(),
        backgroundColor: const Color(0xFF174C3C),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add expense',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<List<Expense>>(
        stream: _provider.watchExpenses(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _errorState(snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF174C3C),
              ),
            );
          }

          final allExpenses = snapshot.data ?? [];

          final todayExpenses = allExpenses.where((expense) {
            final date = expense.createdAt;
            return date.year == _today.year &&
                date.month == _today.month &&
                date.day == _today.day;
          }).toList();

          final monthExpenses = allExpenses.where((expense) {
            return !expense.createdAt.isBefore(_startOfMonth(_today)) &&
                !expense.createdAt.isAfter(_endOfMonth(_today));
          }).toList();

          final todayTotal = todayExpenses.fold<int>(
            0,
            (sum, expense) => sum + expense.amountPaise,
          );

          final monthTotal = monthExpenses.fold<int>(
            0,
            (sum, expense) => sum + expense.amountPaise,
          );

          final filtered = _filterExpenses(allExpenses);

          final filteredTotal = filtered.fold<int>(
            0,
            (sum, expense) => sum + expense.amountPaise,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              _summaryCard(
                monthTotal: monthTotal,
                todayTotal: todayTotal,
                monthCount: monthExpenses.length,
              ),
              const SizedBox(height: 22),
              _sectionHeading('Expense history'),
              const SizedBox(height: 12),
              _searchBox(),
              const SizedBox(height: 15),
              _dateFilters(),
              const SizedBox(height: 13),
              _filterToolbar(filtered.length, filteredTotal),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                _emptyState()
              else
                ..._buildGroupedExpenses(filtered),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // SUMMARY CARD
  // ------------------------------------------------------------

  Widget _summaryCard({
    required int monthTotal,
    required int todayTotal,
    required int monthCount,
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
            color: const Color(0xFF174C3C).withOpacity(.14),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'TOTAL SPENT THIS MONTH',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.13),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  DateFormat('MMMM yyyy').format(DateTime.now()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _money(monthTotal),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '$monthCount expenses recorded this month',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 1,
            color: Colors.white.withOpacity(.2),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _summaryMetric(
                  icon: Icons.today_outlined,
                  label: 'Spent today',
                  value: _money(todayTotal),
                ),
              ),
              Container(
                height: 38,
                width: 1,
                color: Colors.white24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _summaryMetric(
                  icon: Icons.receipt_long_outlined,
                  label: 'This month',
                  value: '$monthCount entries',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _sectionHeading(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  // ------------------------------------------------------------
  // SEARCH
  // ------------------------------------------------------------

  Widget _searchBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE8ECE9)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() => _search = value.trim());
        },
        decoration: InputDecoration(
          hintText: 'Search notes or amounts...',
          hintStyle: const TextStyle(
            color: Colors.black38,
            fontSize: 12,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF28765A),
          ),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _search = '');
                  },
                  icon: const Icon(Icons.close),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // DATE FILTER CHIPS
  // ------------------------------------------------------------

  Widget _dateFilters() {
    final filters = [
      {'id': 'today', 'label': 'Today'},
      {'id': 'yesterday', 'label': 'Yesterday'},
      {'id': 'week', 'label': 'This week'},
      {'id': 'month', 'label': 'This month'},
      {'id': 'all', 'label': 'All time'},
      {'id': 'custom', 'label': 'Custom'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final id = filter['id']!;
          final selected = _dateFilter == id;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter['label']!),
              selected: selected,
              onSelected: (_) {
                if (id == 'custom') {
                  _selectCustomRange();
                } else {
                  setState(() => _dateFilter = id);
                }
              },
              selectedColor: const Color(0xFFDCEDE4),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: selected
                    ? const Color(0xFFB6D6C5)
                    : const Color(0xFFE8ECE9),
              ),
              labelStyle: TextStyle(
                color: selected
                    ? const Color(0xFF174C3C)
                    : Colors.black54,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ------------------------------------------------------------
  // SORT TOOLBAR
  // ------------------------------------------------------------

  Widget _filterToolbar(int count, int total) {
    final sortLabels = {
      'newest': 'Newest first',
      'oldest': 'Oldest first',
      'highest': 'Highest amount',
      'lowest': 'Lowest amount',
    };

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count expenses',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Total: ${_money(total)}',
                style: const TextStyle(
                  color: Color(0xFF28765A),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Sort expenses',
          onSelected: (value) {
            setState(() => _sortOrder = value);
          },
          itemBuilder: (_) {
            return sortLabels.entries.map((entry) {
              return PopupMenuItem<String>(
                value: entry.key,
                child: Row(
                  children: [
                    if (_sortOrder == entry.key)
                      const Icon(
                        Icons.check,
                        size: 17,
                        color: Color(0xFF28765A),
                      )
                    else
                      const SizedBox(width: 17),
                    const SizedBox(width: 8),
                    Text(entry.value),
                  ],
                ),
              );
            }).toList();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFE8ECE9)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.swap_vert_rounded,
                  size: 17,
                  color: Color(0xFF28765A),
                ),
                const SizedBox(width: 5),
                Text(
                  sortLabels[_sortOrder]!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.keyboard_arrow_down, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // GROUP EXPENSES BY DATE
  // ------------------------------------------------------------

  List<Widget> _buildGroupedExpenses(List<Expense> expenses) {
    final grouped = <String, List<Expense>>{};

    for (final expense in expenses) {
      final key = DateFormat('yyyy-MM-dd').format(expense.createdAt);
      grouped.putIfAbsent(key, () => []).add(expense);
    }

    final keys = grouped.keys.toList();

    if (_sortOrder == 'oldest') {
      keys.sort();
    } else if (_sortOrder == 'highest' || _sortOrder == 'lowest') {
      keys.sort((a, b) {
        final aTotal = grouped[a]!.fold<int>(
          0,
          (sum, e) => sum + e.amountPaise,
        );
        final bTotal = grouped[b]!.fold<int>(
          0,
          (sum, e) => sum + e.amountPaise,
        );

        return _sortOrder == 'highest'
            ? bTotal.compareTo(aTotal)
            : aTotal.compareTo(bTotal);
      });
    } else {
      keys.sort((a, b) => b.compareTo(a));
    }

    final widgets = <Widget>[];

    for (final key in keys) {
      final dayExpenses = grouped[key]!;

      final dayTotal = dayExpenses.fold<int>(
        0,
        (sum, expense) => sum + expense.amountPaise,
      );

      final date = dayExpenses.first.createdAt;

      widgets.add(
        _dayHeader(
          date: date,
          count: dayExpenses.length,
          total: dayTotal,
        ),
      );

      widgets.add(const SizedBox(height: 9));

      widgets.addAll(
        dayExpenses.map(_expenseCard),
      );

      widgets.add(const SizedBox(height: 10));
    }

    return widgets;
  }

  Widget _dayHeader({
    required DateTime date,
    required int count,
    required int total,
  }) {
    final isToday = date.year == _today.year &&
        date.month == _today.month &&
        date.day == _today.day;

    final yesterday = _today.subtract(const Duration(days: 1));

    final isYesterday = date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;

    final label = isToday
        ? 'Today'
        : isYesterday
            ? 'Yesterday'
            : DateFormat('EEEE').format(date);

    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _dayFormat.format(date),
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money(total),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF174C3C),
                ),
              ),
              Text(
                '$count ${count == 1 ? 'expense' : 'expenses'}',
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // EXPENSE CARD
  // ------------------------------------------------------------

  Widget _expenseCard(Expense expense) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECE9)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openExpenseForm(expense: expense),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 13,
          ),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3EE),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: Color(0xFF28765A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
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
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _timeFormat.format(expense.createdAt),
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '- ${_money(expense.amountPaise)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: Color(0xFF252B28),
                ),
              ),
              const SizedBox(width: 3),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 19,
                onSelected: (value) {
                  if (value == 'edit') {
                    _openExpenseForm(expense: expense);
                  } else if (value == 'delete') {
                    _confirmDelete(expense);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 9),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 18,
                        ),
                        SizedBox(width: 9),
                        Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // ADD / EDIT EXPENSE
  // ------------------------------------------------------------

  Future<void> _openExpenseForm({Expense? expense}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseFormSheet(
        provider: _provider,
        expense: expense,
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            expense == null
                ? 'Expense saved successfully.'
                : 'Expense updated successfully.',
          ),
          backgroundColor: const Color(0xFF174C3C),
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // DELETE CONFIRMATION
  // ------------------------------------------------------------

  Future<void> _confirmDelete(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete expense?'),
          content: Text(
            'Delete "${expense.note.isEmpty ? 'Expense' : expense.note}" '
            'for ${_money(expense.amountPaise)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _provider.deleteExpense(expense.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense deleted.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete expense: $e')),
      );
    }
  }

  // ------------------------------------------------------------
  // EMPTY / ERROR STATES
  // ------------------------------------------------------------

  Widget _emptyState() {
    final hasFilters = _search.isNotEmpty ||
        _dateFilter != 'month';

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8ECE9)),
      ),
      child: Column(
        children: [
          Container(
            height: 65,
            width: 65,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF3EE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 30,
              color: Color(0xFF28765A),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            hasFilters ? 'No matching expenses' : 'No expenses yet',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilters
                ? 'Try changing your date filter or search.'
                : 'Start recording your daily expenses. '
                    'Your expense history will appear here.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _search = '';
                  _dateFilter = 'month';
                  _sortOrder = 'newest';
                });
              },
              child: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load expenses',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ADD / EDIT EXPENSE BOTTOM SHEET
// ============================================================

class _ExpenseFormSheet extends StatefulWidget {
  final ExpenseProvider provider;
  final Expense? expense;

  const _ExpenseFormSheet({
    required this.provider,
    this.expense,
  });

  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  late DateTime _selectedDate;
  bool _saving = false;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();

    final expense = widget.expense;

    _amountController = TextEditingController(
      text: expense == null
          ? ''
          : (expense.amountPaise / 100).toStringAsFixed(2),
    );

    _noteController = TextEditingController(
      text: expense?.note ?? '',
    );

    _selectedDate = expense?.createdAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _money(int paise) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(paise / 100);
  }

  // ------------------------------------------------------------
  // PICK DATE
  // ------------------------------------------------------------

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'SELECT EXPENSE DATE',
    );

    if (selected == null || !mounted) return;

    setState(() {
      _selectedDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _selectedDate.hour,
        _selectedDate.minute,
      );
    });
  }

  // ------------------------------------------------------------
  // PICK TIME
  // ------------------------------------------------------------

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
      helpText: 'SELECT EXPENSE TIME',
    );

    if (selected == null || !mounted) return;

    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        selected.hour,
        selected.minute,
      );
    });
  }

  // ------------------------------------------------------------
  // SAVE
  // ------------------------------------------------------------

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', ''),
    );

    if (amount == null || amount <= 0) return;

    final amountPaise = (amount * 100).round();

    setState(() => _saving = true);

    try {
      if (_isEditing) {
        await widget.provider.updateExpense(
          expenseId: widget.expense!.id,
          amountPaise: amountPaise,
          note: _noteController.text.trim(),
          date: _selectedDate,
        );
      } else {
        await widget.provider.addExpense(
          amountPaise: amountPaise,
          note: _noteController.text.trim(),
          date: _selectedDate,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save expense: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        13,
        20,
        20 + bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(27),
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
                  height: 4,
                  width: 42,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    height: 45,
                    width: 45,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3EE),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF28765A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Edit expense' : 'Add expense',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Record your spending in seconds',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // AMOUNT
              const Text(
                'EXPENSE AMOUNT',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F8F6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE1EAE4),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      '₹',
                      style: TextStyle(
                        fontSize: 28,
                        color: Color(0xFF174C3C),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _amountController,
                        autofocus: !_isEditing,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF174C3C),
                        ),
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            color: Colors.black26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        validator: (value) {
                          final amount = double.tryParse(
                            (value ?? '').trim().replaceAll(',', ''),
                          );

                          if (amount == null || amount <= 0) {
                            return 'Enter a valid amount';
                          }

                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // NOTE
              const Text(
                'NOTE',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'What did you spend on?',
                  hintStyle: const TextStyle(
                    color: Colors.black38,
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(
                    Icons.edit_note_rounded,
                    color: Color(0xFF28765A),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAF9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFFE8ECE9),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFFE8ECE9),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF28765A),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // DATE AND TIME
              const Text(
                'DATE & TIME',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: _dateTimeButton(
                      icon: Icons.calendar_month_outlined,
                      label: DateFormat('dd MMM yyyy')
                          .format(_selectedDate),
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _dateTimeButton(
                      icon: Icons.access_time_rounded,
                      label: DateFormat('hh:mm a')
                          .format(_selectedDate),
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // SAVE
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF174C3C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isEditing
                              ? 'Update expense'
                              : 'Save expense',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'This expense will not change any account balance.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateTimeButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F8F6),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFE5ECE7)),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 17,
              color: const Color(0xFF28765A),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
