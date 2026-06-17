import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/app_drawer.dart';
import 'login_screen.dart';
import 'dashboard_tab.dart';
import 'active_order_flow.dart';
import 'earnings_tab.dart';
import 'profile_tab.dart';

class MainNavigation extends StatelessWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;

        if (!state.isLoggedIn) {
          return const LoginScreen();
        }

        Widget body;
        if (state.currentTab == 0) {
          if (state.orderState == OrderState.navToRestaurant ||
              state.orderState == OrderState.verifyItems ||
              state.orderState == OrderState.navToCustomer ||
              state.orderState == OrderState.confirmDelivery ||
              state.orderState == OrderState.completed) {
            body = const ActiveOrderFlow();
          } else {
            body = const DashboardTab();
          }
        } else if (state.currentTab == 1) {
          body = const EarningsTab();
        } else {
          body = const ProfileTab();
        }

        final hideBottomNav = state.currentTab == 0 &&
            (state.orderState == OrderState.navToRestaurant ||
                state.orderState == OrderState.verifyItems ||
                state.orderState == OrderState.navToCustomer ||
                state.orderState == OrderState.confirmDelivery ||
                state.orderState == OrderState.completed);

        return Scaffold(
          backgroundColor: AppColors.background,
          drawer: const AppDrawer(),
          body: body,
          bottomNavigationBar: hideBottomNav
              ? null
              : Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: BottomNavigationBar(
              currentIndex: state.currentTab,
              onTap: (index) => state.setTab(index),
              backgroundColor: AppColors.surface,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.navInactive,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              iconSize: 22,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.assignment_rounded),
                  ),
                  label: 'Tasks',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.payments_rounded),
                  ),
                  label: 'Earnings',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.person_rounded),
                  ),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
