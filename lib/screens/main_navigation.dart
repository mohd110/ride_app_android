import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/permission_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_drawer.dart';
import 'login_screen.dart';
import 'dashboard_tab.dart';
import 'active_order_flow.dart';
import 'earnings_tab.dart';
import 'profile_tab.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  bool _permissionsRequested = false;

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    // Request permissions the first time the rider arrives at the dashboard
    // (i.e. just after login). Using addPostFrameCallback so the dialog has
    // a valid context and the build cycle is complete.
    if (AppState.instance.isLoggedIn && !_permissionsRequested) {
      _permissionsRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          PermissionService.requestAll(context);
        }
      });
    }
    // Reset flag when rider logs out so permissions are re-requested on
    // the next login (in case they were skipped previously).
    if (!AppState.instance.isLoggedIn) {
      _permissionsRequested = false;
    }
  }

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
