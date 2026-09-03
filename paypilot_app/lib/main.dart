import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/wallet_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/schedule_payment_screen.dart';
import 'screens/smart_pay_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WalletService.init();
  runApp(const PayPilotApp());
}

class PayPilotApp extends StatelessWidget {
  const PayPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PayPilot — Automated Payment Scheduling on BMONI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF7526C9),
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7526C9),
          secondary: Color(0xFFB368F7),
          surface: Color(0xFF161B22),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B22),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        useMaterial3: true,
      ),
      home: const RootNavigator(),
    );
  }
}

class RootNavigator extends StatefulWidget {
  const RootNavigator({super.key});

  @override
  State<RootNavigator> createState() => _RootNavigatorState();
}

class _RootNavigatorState extends State<RootNavigator> {
  bool _isLoading = true;
  bool _isOnboarded = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    try {
      final userRes = await ApiService.getCurrentUser();
      if (userRes['user'] != null && userRes['wallet'] != null) {
        setState(() {
          _isOnboarded = true;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    setState(() {
      _isOnboarded = false;
      _isLoading = false;
    });
  }

  int _homeRefreshKey = 0;
  int _scheduleRefreshKey = 0;
  int _smartPayRefreshKey = 0;

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 0) _homeRefreshKey++;
      if (index == 1) _scheduleRefreshKey++;
      if (index == 2) _smartPayRefreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1117),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFB368F7)),
        ),
      );
    }

    if (!_isOnboarded) {
      return OnboardingScreen(
        onOnboarded: () {
          setState(() {
            _isOnboarded = true;
            _currentIndex = 0;
            _homeRefreshKey++;
          });
        },
      );
    }

    final screens = [
      HomeScreen(
        key: ValueKey('home_$_homeRefreshKey'),
        onNavigateToSmartCheck: () => _navigateToTab(2),
        onNavigateToSchedule: () => _navigateToTab(1),
      ),
      SchedulePaymentScreen(
        key: ValueKey('schedule_$_scheduleRefreshKey'),
        onPaymentScheduled: () => _navigateToTab(0),
      ),
      SmartPayScreen(
        key: ValueKey('smartpay_$_smartPayRefreshKey'),
        onFundWalletTapped: () => _navigateToTab(0),
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF30363D), width: 0.8)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _navigateToTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF161B22),
          selectedItemColor: const Color(0xFFB368F7),
          unselectedItemColor: const Color(0xFF8B949E),
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.send_outlined),
              activeIcon: Icon(Icons.send_rounded),
              label: 'Schedule',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.verified_outlined),
              activeIcon: Icon(Icons.verified_rounded),
              label: 'Smart Pay',
            ),
          ],
        ),
      ),
    );
  }
}
