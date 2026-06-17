import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';

/// Reusable detail/info page shell used across settings and support flows.
class DetailPageScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? bottomAction;

  const DetailPageScaffold({
    Key? key,
    required this.title,
    required this.children,
    this.bottomAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
      bottomNavigationBar: bottomAction != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: bottomAction,
              ),
            )
          : null,
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const InfoRow({Key? key, required this.label, required this.value, this.valueColor}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class TappableMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  const TappableMenuTile({
    Key? key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.surfaceAccent,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor ?? AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Text(subtitle!, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class StatHighlightCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const StatHighlightCard({
    Key? key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            Icon(icon, color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
