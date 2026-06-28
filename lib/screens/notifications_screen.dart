import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/detail_page_scaffold.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;
        final items = state.notifications;
        final unread = state.unreadNotifications;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Notifications'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              if (unread > 0)
                TextButton(
                  onPressed: () => state.markAllNotificationsRead(),
                  child: const Text('Mark all read', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          body: items.isEmpty
              ? const Center(
                  child: Text(
                    'No notifications yet',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return InkWell(
                      onTap: () {
                        state.markNotificationRead(item.id);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => NotificationDetailScreen(notification: item),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: AppCard(
                        color: item.isRead ? AppColors.surface : AppColors.surfaceAccent,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAccent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(_icon(item.type), color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 14,
                                            fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (!item.isRead)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(item.time, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  IconData _icon(String type) {
    switch (type) {
      case 'order_assigned':
        return Icons.assignment_rounded;
      case 'picked_up':
        return Icons.shopping_bag_rounded;
      case 'delivered':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'payment_received':
        return Icons.payments_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}

class NotificationDetailScreen extends StatelessWidget {
  final NotificationItem notification;

  const NotificationDetailScreen({Key? key, required this.notification}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DetailPageScaffold(
      title: 'Notification',
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.title,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(notification.time, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider()),
              Text(
                notification.body,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ),
      ],
      bottomAction: ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Dismiss'),
      ),
    );
  }
}
