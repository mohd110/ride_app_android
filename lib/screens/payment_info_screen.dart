import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/detail_page_scaffold.dart';

class PaymentInfoScreen extends StatelessWidget {
  const PaymentInfoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final p = MockData.payment;

    return DetailPageScaffold(
      title: 'Payment Info',
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Direct Deposit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 12),
              InfoRow(label: 'Bank', value: p.bankName),
              InfoRow(label: 'Account', value: p.accountMasked),
              InfoRow(label: 'Schedule', value: p.payoutSchedule),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Last Payout', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              Text(
                '\$${p.lastPayoutAmount.toStringAsFixed(2)}',
                style: const TextStyle(color: AppColors.primary, fontSize: 28, fontWeight: FontWeight.w800),
              ),
              Text('Deposited on ${p.lastPayout}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('This week (pending)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              SizedBox(height: 8),
              InfoRow(label: 'Delivery fees', value: '\$98.00'),
              InfoRow(label: 'Tips', value: '\$34.50', valueColor: AppColors.success),
              InfoRow(label: 'Incentives', value: '\$10.00'),
              Divider(),
              InfoRow(label: 'Estimated payout', value: '\$142.50', valueColor: AppColors.primary),
            ],
          ),
        ),
      ],
      bottomAction: OutlinedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bank update request submitted for review.')),
          );
        },
        child: const Text('Update Bank Details'),
      ),
    );
  }
}
