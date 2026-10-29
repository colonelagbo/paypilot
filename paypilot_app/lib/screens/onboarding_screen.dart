import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'connect_bank_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onOnboarded;

  const OnboardingScreen({super.key, required this.onOnboarded});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 1; // 1: Create Account, 2: Connect Bank Account

  final _nameController = TextEditingController(text: 'Adewale Johnson');
  final _businessController = TextEditingController(text: 'Adewale Logistics & Tech Ltd');
  final _emailController = TextEditingController(text: 'adewale@logistics.ng');
  final _passwordController = TextEditingController(text: 'securePassword123');

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _createAccount() async {
    final name = _nameController.text.trim();
    final business = _businessController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || business.isEmpty || email.isEmpty) {
      setState(() => _errorMessage = 'Please complete all required fields.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.createAccount(
        name: name,
        businessName: business,
        email: email,
        password: _passwordController.text.trim(),
      );

      if (res['success'] == true) {
        setState(() {
          _isLoading = false;
          _step = 2; // Transition immediately to Step 2: Connect Bank Account
        });
      } else {
        throw Exception(res['error'] ?? 'Failed to create account');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 2) {
      return ConnectBankScreen(
        isInitialSetup: true,
        onBankConnected: widget.onOnboarded,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo & Header
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7526C9).withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF7526C9), width: 2),
                      ),
                      child: const Icon(
                        Icons.rocket_launch_rounded,
                        size: 44,
                        color: Color(0xFFB368F7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'PayPilot',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Automated Business Payment & Payroll Scheduling',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF8B949E),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Step indicator
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7526C9).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF7526C9).withOpacity(0.3)),
                      ),
                      child: const Text(
                        'Step 1 of 2: Create Account',
                        style: TextStyle(
                          color: Color(0xFFB368F7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Account Input Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Set up your business credentials. Next, you will connect your bank account.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF8B949E)),
                        ),
                        const SizedBox(height: 20),

                        // Owner Name
                        const Text('Full Name / Account Owner', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0D1117),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                            hintText: 'e.g. Adewale Johnson',
                            hintStyle: const TextStyle(color: Color(0xFF484F58)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Business Name
                        const Text('Business / Organization Name', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _businessController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0D1117),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                            hintText: 'e.g. Adewale Logistics Ltd',
                            hintStyle: const TextStyle(color: Color(0xFF484F58)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Email
                        const Text('Work Email Address', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0D1117),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                            hintText: 'e.g. admin@company.com',
                            hintStyle: const TextStyle(color: Color(0xFF484F58)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password
                        const Text('Password', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0D1117),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                            hintText: '••••••••',
                            hintStyle: const TextStyle(color: Color(0xFF484F58)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFFFF7B72), fontSize: 13),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Create Account CTA
                  ElevatedButton(
                    onPressed: _isLoading ? null : _createAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7526C9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                              SizedBox(width: 10),
                              Text('Creating Account...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_forward_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('Create Account & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
