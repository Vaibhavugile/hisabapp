
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';

import '../business/business_screen.dart';
import '../personal/personal_screen.dart';
import '../recurring/recurring_payments_screen.dart';
import '../expenses/expenses_screen.dart';

import 'dashboard_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _index = 0;

  static const Color _green = Color(0xFF087B50);
  static const Color _darkGreen = Color(0xFF064E38);

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().strings;

    final pages = [
      const DashboardScreen(),
      const BusinessScreen(),
      const PersonalScreen(),
      const RecurringPaymentsScreen(),
      const ExpensesScreen(),
      const _ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 70,
          backgroundColor: Colors.white,
          elevation: 12,
          indicatorColor: const Color(0xFFE6F3EB),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            return TextStyle(
              fontSize: 10,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? _green
                  : Colors.grey.shade600,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            return IconThemeData(
              size: 22,
              color: states.contains(WidgetState.selected)
                  ? _green
                  : Colors.grey.shade600,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) {
            setState(() => _index = value);
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: s.t('home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.storefront_outlined),
              selectedIcon: const Icon(Icons.storefront_rounded),
              label: s.t('business'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.people_outline_rounded),
              selectedIcon: const Icon(Icons.people_rounded),
              label: s.t('personal'),
            ),
            const NavigationDestination(
              icon: Icon(Icons.event_repeat_outlined),
              selectedIcon: Icon(Icons.event_repeat_rounded),
              label: 'Recurring',
            ),
            const NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments_rounded),
              label: 'Expenses',
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: s.t('profile'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PREMIUM PROFILE SCREEN
// ============================================================

class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen();

  static const Color _green = Color(0xFF087B50);
  static const Color _darkGreen = Color(0xFF064E38);
  static const Color _background = Color(0xFFF5F8F6);
  static const Color _border = Color(0xFFE7EEE9);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<HisaabAuthProvider>().user;
    final lang = context.watch<LanguageProvider>();
    final s = lang.strings;

    final phone = user?.phoneNumber ?? 'Hisaab user';
    final initial = phone.isNotEmpty
        ? phone.substring(0, 1).toUpperCase()
        : 'H';

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(21, 22, 21, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MY ACCOUNT',
                            style: TextStyle(
                              color: _green,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.8,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Profile',
                            style: TextStyle(
                              color: Color(0xFF172B22),
                              fontSize: 29,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: _border),
                      ),
                      child: const Icon(
                        Icons.settings_outlined,
                        color: _darkGreen,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Profile hero
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 25, 20, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(23),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF075C40),
                        Color(0xFF087B50),
                        Color(0xFF119768),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(27),
                    boxShadow: [
                      BoxShadow(
                        color: _green.withValues(alpha: 0.19),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -30,
                        top: -40,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.055),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 65,
                                height: 65,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.17),
                                  borderRadius: BorderRadius.circular(21),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 29,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Welcome to Hisaab',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      phone,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.verified_rounded,
                                color: Color(0xFFB8F2D0),
                                size: 23,
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),
                          Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.17),
                          ),
                          const SizedBox(height: 17),
                          Row(
                            children: [
                              const Icon(
                                Icons.shield_rounded,
                                color: Color(0xFFB8F2D0),
                                size: 17,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Your account is securely connected',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Account section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(21, 29, 21, 12),
                child: const Text(
                  'ACCOUNT PREFERENCES',
                  style: TextStyle(
                    color: Color(0xFF77847C),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),

            // Language card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      _iconBox(Icons.language_rounded),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.t('language'),
                              style: const TextStyle(
                                color: Color(0xFF1D3026),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Choose your preferred language',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: lang.locale,
                          borderRadius: BorderRadius.circular(14),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: _green,
                          ),
                          style: const TextStyle(
                            color: _darkGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'en',
                              child: Text('English'),
                            ),
                            DropdownMenuItem(
                              value: 'hi',
                              child: Text('हिन्दी'),
                            ),
                            DropdownMenuItem(
                              value: 'mr',
                              child: Text('मराठी'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              lang.setLanguage(value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // About section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(21, 29, 21, 12),
                child: const Text(
                  'ABOUT HISAAB',
                  style: TextStyle(
                    color: Color(0xFF77847C),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    children: [
                      _aboutRow(
                        icon: Icons.account_balance_wallet_rounded,
                        title: 'Hisaab',
                        subtitle: 'Your business and personal ledger',
                      ),
                      const SizedBox(height: 18),
                      Divider(color: _border, height: 1),
                      const SizedBox(height: 18),
                      _aboutRow(
                        icon: Icons.security_rounded,
                        title: 'Secure account',
                        subtitle: 'Protected with phone authentication',
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Logout
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(19),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(19),
                    onTap: () => _confirmLogout(context, s),
                    child: Container(
                      padding: const EdgeInsets.all(17),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(
                          color: const Color(0xFFF1DDDD),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 43,
                            height: 43,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEEEE),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.logout_rounded,
                              color: Color(0xFFD64545),
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.t('logout'),
                                  style: const TextStyle(
                                    color: Color(0xFFC43F3F),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Sign out from your Hisaab account',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Color(0xFFD64545),
                            size: 15,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Footer
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 29, 20, 25),
                child: Column(
                  children: [
                    const Text(
                      'HISAAB',
                      style: TextStyle(
                        color: _green,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Manage money. Stay in control.',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5EF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: _green, size: 21),
    );
  }

  Widget _aboutRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        _iconBox(icon),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1D3026),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmLogout(
    BuildContext context,
    dynamic strings,
  ) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Sign out?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF172B22),
            ),
          ),
          content: const Text(
            'Are you sure you want to sign out of your Hisaab account?',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD64545),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && context.mounted) {
      await context.read<HisaabAuthProvider>().signOut();
    }
  }
}
