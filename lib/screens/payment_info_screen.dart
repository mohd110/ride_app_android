import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/order_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/detail_page_scaffold.dart';

const _monthAbbrev = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _formatDate(DateTime d) => '${_monthAbbrev[d.month - 1]} ${d.day}, ${d.year}';

class PaymentInfoScreen extends StatelessWidget {
  const PaymentInfoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;
        final paidTotal = state.payouts.where((p) => p.status == 'paid').fold(0.0, (sum, p) => sum + p.amount);

        return DetailPageScaffold(
          title: 'Wallet',
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('WALLET BALANCE', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text(
                    '₹${state.walletBalance.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.primary, fontSize: 32, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text('Earned but not yet included in a payout', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('LIFETIME EARNED', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('₹${state.lifetimeEarnings.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TOTAL PAID OUT', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('₹${paidTotal.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.success, fontSize: 16, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Payout History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            if (state.payouts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No payouts yet. Your restaurant settles rider earnings periodically — they\'ll show up here once recorded.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              )
            else
              ...state.payouts.map((payout) => _buildPayoutTile(payout)),
          ],
        );
      },
    );
  }

  Widget _buildPayoutTile(RiderPayout payout) {
    final isPaid = payout.status == 'paid';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPaid ? Icons.check_circle_rounded : Icons.schedule_rounded,
                color: isPaid ? AppColors.success : AppColors.warning,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_formatDate(payout.periodStart)} – ${_formatDate(payout.periodEnd)}',
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text(
                    isPaid && payout.paidAt != null ? 'Paid on ${_formatDate(payout.paidAt!)}' : 'Pending',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Text(
              '₹${payout.amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: isPaid ? AppColors.success : AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
