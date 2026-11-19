
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';

class TransactionDetailsScreen extends StatelessWidget {
  final String accountName;
  final Map<String, dynamic> transaction;
  final bool isOwner;

  const TransactionDetailsScreen({
    super.key,
    required this.accountName,
    required this.transaction,
    required this.isOwner,
  });

  DateTime? _dateValue(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return value.toDate();
    } catch (_) {
      return DateTime.tryParse(value.toString());
    }
  }

  String _formatDate(dynamic value) {
    final date = _dateValue(value);
    return date == null
        ? 'Not available'
        : DateFormat('dd MMM yyyy').format(date);
  }

  String _formatDateTime(dynamic value) {
    final date = _dateValue(value);
    return date == null
        ? 'Not available'
        : DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'bill':
        return 'Purchase / Bill';
      case 'payment':
        return 'Payment';
      case 'money_lent':
        return 'Money given';
      case 'money_received':
        return 'Money received back';
      case 'money_borrowed':
        return 'Money borrowed';
      case 'repayment_paid':
        return 'Repayment made';
      default:
        return type;
    }
  }

  String _paymentLabel(String? value) {
    switch (value) {
      case 'cash':
        return 'Cash';
      case 'upi':
        return 'UPI';
      case 'bank_transfer':
        return 'Bank transfer';
      case 'cheque':
        return 'Cheque';
      case 'other':
        return 'Other';
      default:
        return value?.isNotEmpty == true ? value! : 'Not specified';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending confirmation';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Approved';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return AppTheme.green;
    }
  }

  bool _isImage(String url, String mimeType, String fileName) {
    final lowerUrl = url.toLowerCase();
    final lowerName = fileName.toLowerCase();

    return mimeType.startsWith('image/') ||
        lowerUrl.contains('.jpg') ||
        lowerUrl.contains('.jpeg') ||
        lowerUrl.contains('.png') ||
        lowerUrl.contains('.webp') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp');
  }

  Future<void> _openAttachment(
    BuildContext context,
    String url,
  ) async {
    try {
      final uri = Uri.parse(url);

      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open this attachment.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open attachment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = transaction['type']?.toString() ?? '';
    final status = transaction['status']?.toString() ?? 'approved';

    final amountPaise =
        (transaction['amountPaise'] as num?)?.toInt() ?? 0;

    final ownerDelta =
        (transaction['ownerDeltaPaise'] as num?)?.toInt() ?? 0;

    final effectiveDelta = isOwner ? ownerDelta : -ownerDelta;
    final isPositive = effectiveDelta >= 0;

    final description =
        transaction['description']?.toString().trim() ?? '';

    final billNumber =
        transaction['billNumber']?.toString().trim() ?? '';

    final reference =
        transaction['referenceNumber']?.toString().trim() ?? '';

    final paymentMode =
        transaction['paymentMode']?.toString();

    final attachmentUrl =
        transaction['attachmentUrl']?.toString() ?? '';

    final attachmentName =
        transaction['attachmentName']?.toString() ?? 'Attachment';

    final attachmentType =
        transaction['attachmentType']?.toString() ?? '';

    final createdByName =
        transaction['createdByName']?.toString().trim().isNotEmpty == true
            ? transaction['createdByName'].toString().trim()
            : 'Unknown member';

    final createdByRole =
        transaction['createdByRole']?.toString() ?? '';

    final approvedByName =
        transaction['approvedByName']?.toString() ?? '';

    final rejectedByName =
        transaction['rejectedByName']?.toString() ?? '';

    final rejectionReason =
        transaction['rejectionReason']?.toString() ?? '';

    final hasAttachment = attachmentUrl.startsWith('http');

    final isImage = hasAttachment &&
        _isImage(attachmentUrl, attachmentType, attachmentName);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      appBar: AppBar(
        title: const Text('Transaction details'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
        children: [
          // Amount card.
          Container(
            padding: const EdgeInsets.all(22),
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
                  _typeLabel(type).toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .75),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '₹ ${(amountPaise / 100).toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${isPositive ? '+' : '−'} ₹ ${(effectiveDelta.abs() / 100).toStringAsFixed(2)} from your perspective',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .85),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isOwner
                      ? 'Shown from the account owner’s perspective'
                      : 'Shown from your perspective as the shared member',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .72),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          _section(
            title: 'Account information',
            icon: Icons.account_balance_wallet_outlined,
            children: [
              _detailRow('Account', accountName),
              _detailRow('Transaction type', _typeLabel(type)),
              _detailRow(
                'Transaction date',
                _formatDateTime(transaction['transactionDate']),
              ),
              _detailRow(
                'Created on',
                _formatDateTime(transaction['createdAt']),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _section(
            title: 'Transaction information',
            icon: Icons.receipt_long_outlined,
            children: [
              if (description.isNotEmpty)
                _detailRow('Description', description),
              if (billNumber.isNotEmpty)
                _detailRow('Bill / invoice number', billNumber),
              if (type == 'bill')
                _detailRow(
                  'Due date',
                  _formatDate(transaction['dueDate']),
                ),
              _detailRow(
                'Amount',
                '₹ ${(amountPaise / 100).toStringAsFixed(2)}',
              ),
              if (type == 'payment' ||
                  type == 'money_received' ||
                  type == 'repayment_paid')
                _detailRow(
                  'Payment method',
                  _paymentLabel(paymentMode),
                ),
              if (reference.isNotEmpty)
                _detailRow('Payment reference', reference),
            ],
          ),

          const SizedBox(height: 16),

          _section(
            title: 'Added by',
            icon: Icons.person_outline,
            children: [
              _detailRow('Name', createdByName),
              _detailRow(
                'Account role',
                createdByRole == 'owner'
                    ? 'Account owner'
                    : createdByRole == 'linked_user'
                        ? 'Linked user'
                        : 'Member',
              ),
              _detailRow(
                'User ID',
                transaction['createdBy']?.toString() ?? 'Not available',
              ),
            ],
          ),

          const SizedBox(height: 16),

          _section(
            title: 'Approval information',
            icon: Icons.verified_outlined,
            children: [
              _detailRow('Status', _statusLabel(status)),
              if (status == 'approved' && approvedByName.isNotEmpty)
                _detailRow('Approved by', approvedByName),
              if (status == 'approved')
                _detailRow(
                  'Approved on',
                  _formatDateTime(transaction['approvedAt']),
                ),
              if (status == 'rejected' && rejectedByName.isNotEmpty)
                _detailRow('Rejected by', rejectedByName),
              if (status == 'rejected')
                _detailRow(
                  'Rejected on',
                  _formatDateTime(transaction['rejectedAt']),
                ),
              if (status == 'rejected' && rejectionReason.isNotEmpty)
                _detailRow('Rejection reason', rejectionReason),
            ],
          ),

          const SizedBox(height: 16),

          _section(
            title: 'Attachment',
            icon: Icons.attach_file,
            children: [
              if (!hasAttachment)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No attachment was added to this transaction.',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                )
              else ...[
                if (isImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      attachmentUrl,
                      width: double.infinity,
                      height: 260,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          height: 180,
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stack) {
                        return const SizedBox(
                          height: 130,
                          child: Center(
                            child: Text(
                              'Unable to preview image. Try opening it below.',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppTheme.green.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.green.withValues(alpha: .18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isImage
                            ? Icons.image_outlined
                            : Icons.picture_as_pdf_outlined,
                        color: AppTheme.green,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          attachmentName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        _openAttachment(context, attachmentUrl),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(
                      isImage ? 'Open full image' : 'Open attachment',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.green, size: 20),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 5),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
