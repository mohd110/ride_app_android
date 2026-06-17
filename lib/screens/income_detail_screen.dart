import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/detail_page_scaffold.dart';

class IncomeDetailScreen extends StatelessWidget {
  final String title;
  final String amount;
  final String description;
  final List<Map<String, String>> lineItems;

  const IncomeDetailScreen({
    Key? key,
    required this.title,
    required this.amount,
    required this.description,
    required this.lineItems,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DetailPageScaffold(
      title: title,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(amount, style: const TextStyle(color: AppColors.primary, fontSize: 32, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Breakdown', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 10),
        ...lineItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(item['label']!, style: const TextStyle(fontSize: 13))),
                    Text(item['value']!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}
