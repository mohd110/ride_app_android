import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMenuTap;
  final VoidCallback? onNotificationTap;
  final Widget? leading;
  final int? notificationBadge;

  const AppHeader({
    Key? key,
    required this.title,
    this.onMenuTap,
    this.onNotificationTap,
    this.leading,
    this.notificationBadge,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          leading ??
              IconButton(
                onPressed: onMenuTap ?? () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded, color: AppColors.primary),
              ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onNotificationTap,
                icon: const Icon(Icons.notifications_none_rounded, color: AppColors.primary),
              ),
              if (notificationBadge != null && notificationBadge! > 0)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: Text(
                      '${notificationBadge! > 9 ? '9+' : notificationBadge}',
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
