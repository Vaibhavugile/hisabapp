
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/account_provider.dart';

class TransactionFormScreen extends StatefulWidget {
  final String accountId;
  final String accountType;
  final String accountName;
  final String initialType;

  const TransactionFormScreen({
    super.key,
    required this.accountId,
    required this.accountType,
    required this.accountName,
    required this.initialType,
  });

  @override
  State<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _billController = TextEditingController();
  final _referenceController = TextEditingController();

  final _picker = ImagePicker();

  late String _type;

  String _paymentMode = 'cash';

  DateTime _date = DateTime.now();
  DateTime? _dueDate;

  File? _attachment;
  String? _attachmentName;

  bool _saving = false;

  bool get _isBusiness => widget.accountType == 'business';

  bool get _isBill =>
      _type == 'bill' ||
      _type == 'money_lent' ||
      _type == 'money_borrowed';

  // Hide payment details only for business purchases.
  bool get _showPaymentInformation =>
      !(_isBusiness && _type == 'bill');

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _billController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final types = _isBusiness
        ? const {
            'bill': 'Add bill / purchase',
            'payment': 'Record payment',
          }
        : const {
            'money_lent': 'Money given (lent)',
            'money_received': 'Money received back',
            'money_borrowed': 'Money borrowed',
            'repayment_paid': 'Repayment made',
          };

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isBusiness
              ? 'Add business entry'
              : 'Add personal entry',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              _accountHeader(),

              const SizedBox(height: 22),

              _sectionTitle('Transaction information'),

              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Transaction type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: types.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _type = value);
                      },
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  prefixIcon: Icon(Icons.currency_rupee),
                  hintText: 'Enter amount',
                ),
                validator: (value) {
                  final amount = double.tryParse(
                    (value ?? '').trim(),
                  );

                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount';
                  }

                  if ((amount * 100).round() <= 0) {
                    return 'Amount is too small';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                minLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description / Notes',
                  hintText: 'Add transaction details...',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),

              if (_isBusiness && _type == 'bill') ...[
                const SizedBox(height: 15),
                TextFormField(
                  controller: _billController,
                  decoration: const InputDecoration(
                    labelText: 'Bill / Invoice number',
                    hintText: 'Optional',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              _sectionTitle('Date and time'),

              _dateTile(
                label: 'Transaction date',
                value: _date,
                onChanged: (date) {
                  setState(() => _date = date);
                },
              ),

              const SizedBox(height: 10),

              _timeTile(),

              if (_isBusiness && _type == 'bill') ...[
                const SizedBox(height: 10),
                _dateTile(
                  label: 'Payment due date',
                  value: _dueDate,
                  clearable: true,
                  onChanged: (date) {
                    setState(() => _dueDate = date);
                  },
                ),
              ],

              // Payment Information is hidden for business purchases.
              if (_showPaymentInformation) ...[
                const SizedBox(height: 24),

                _sectionTitle('Payment information'),

                DropdownButtonFormField<String>(
                  value: _paymentMode,
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                    prefixIcon: Icon(
                      Icons.account_balance_wallet_outlined,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'cash',
                      child: Text('Cash'),
                    ),
                    DropdownMenuItem(
                      value: 'upi',
                      child: Text('UPI'),
                    ),
                    DropdownMenuItem(
                      value: 'bank_transfer',
                      child: Text('Bank transfer'),
                    ),
                    DropdownMenuItem(
                      value: 'cheque',
                      child: Text('Cheque'),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text('Other'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          setState(() {
                            _paymentMode = value ?? 'cash';
                          });
                        },
                ),

                const SizedBox(height: 15),

                TextFormField(
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Payment reference',
                    hintText:
                        'UPI ID, transaction ID, cheque number...',
                    prefixIcon: Icon(Icons.tag),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              _sectionTitle('Bill / receipt attachment'),

              Text(
                'Attach a photo of the bill, payment receipt, '
                'or an original PDF document.',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 13),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _takePhoto,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _pickImage,
                      icon: const Icon(
                        Icons.photo_library_outlined,
                      ),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 9),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _pickPdf,
                  icon: const Icon(
                    Icons.picture_as_pdf_outlined,
                  ),
                  label: const Text('Choose PDF'),
                ),
              ),

              if (_attachmentName != null) ...[
                const SizedBox(height: 12),
                _attachmentPreview(),
              ],

              const SizedBox(height: 30),

              SizedBox(
                height: 55,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 23,
                          height: 23,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save transaction',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.green.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: AppTheme.green.withValues(alpha: .15),
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppTheme.green,
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.accountName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _isBusiness
                      ? 'Business account'
                      : 'Personal account',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.verified_outlined,
            color: AppTheme.green,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onChanged,
    bool clearable = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(15),
        color: Colors.white,
      ),
      child: ListTile(
        leading: const Icon(
          Icons.calendar_month_outlined,
          color: AppTheme.green,
        ),
        title: Text(label),
        subtitle: Text(
          value == null
              ? 'Not set'
              : DateFormat('dd MMM yyyy').format(value),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (clearable && value != null)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _saving
                    ? null
                    : () {
                        setState(() => _dueDate = null);
                      },
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: _saving
            ? null
            : () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: value ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );

                if (selected == null || !mounted) return;

                if (value == null) {
                  onChanged(
                    DateTime(
                      selected.year,
                      selected.month,
                      selected.day,
                    ),
                  );
                } else {
                  onChanged(
                    DateTime(
                      selected.year,
                      selected.month,
                      selected.day,
                      value.hour,
                      value.minute,
                    ),
                  );
                }
              },
      ),
    );
  }

  Widget _timeTile() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(15),
        color: Colors.white,
      ),
      child: ListTile(
        leading: const Icon(
          Icons.access_time,
          color: AppTheme.green,
        ),
        title: const Text('Transaction time'),
        subtitle: Text(
          DateFormat('hh:mm a').format(_date),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _saving
            ? null
            : () async {
                final selected = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_date),
                );

                if (selected == null || !mounted) return;

                setState(() {
                  _date = DateTime(
                    _date.year,
                    _date.month,
                    _date.day,
                    selected.hour,
                    selected.minute,
                  );
                });
              },
      ),
    );
  }

  Widget _attachmentPreview() {
    final isImage = _attachmentName != null &&
        !_attachmentName!.toLowerCase().endsWith('.pdf');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.green.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppTheme.green.withValues(alpha: .2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isImage
                ? Icons.image_outlined
                : Icons.picture_as_pdf_outlined,
            color: AppTheme.green,
            size: 27,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _attachmentName!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            onPressed: _saving
                ? null
                : () {
                    setState(() {
                      _attachment = null;
                      _attachmentName = null;
                    });
                  },
            icon: const Icon(
              Icons.close,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _takePhoto() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image == null || !mounted) return;

      setState(() {
        _attachment = File(image.path);
        _attachmentName = image.name;
      });
    } catch (e) {
      _showError('Unable to open camera: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null || !mounted) return;

      setState(() {
        _attachment = File(image.path);
        _attachmentName = image.name;
      });
    } catch (e) {
      _showError('Unable to select image: $e');
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final path = file.path;

      if (path == null) {
        _showError('Unable to access the selected PDF file.');
        return;
      }

      if (!mounted) return;

      setState(() {
        _attachment = File(path);
        _attachmentName = file.name;
      });
    } catch (e) {
      _showError('Could not select PDF: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(
      _amountController.text.trim(),
    );

    if (amount == null || amount <= 0) return;

    final amountPaise = (amount * 100).round();

    if (amountPaise <= 0) return;

    if (_dueDate != null &&
        _dueDate!.isBefore(
          DateTime(_date.year, _date.month, _date.day),
        )) {
      _showError(
        'Due date cannot be before the transaction date.',
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await context.read<AccountProvider>().addLedgerTransaction(
        accountId: widget.accountId,
        type: _type,
        amountPaise: amountPaise,
        description: _descriptionController.text.trim(),
        transactionDate: _date,
        paymentMode: _paymentMode,
        billNumber: _billController.text.trim(),
        referenceNumber: _referenceController.text.trim(),
        dueDate: _dueDate,
        attachment: _attachment,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction saved successfully'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      _showError('Could not save transaction: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
