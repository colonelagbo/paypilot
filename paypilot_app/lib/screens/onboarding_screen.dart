import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import '../services/api_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onOnboarded;

  const OnboardingScreen({super.key, required this.onOnboarded});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController(text: 'Bunch Dillon');
  final _businessController = TextEditingController(text: 'Acme Technologies Ltd');
  final _emailController = TextEditingController(text: 'bunch.dillon@example.com');
  bool _isLoading = false;
  String? _statusMessage;
  String? _errorMessage;

  Future<void> _createWallet() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Provisioning on-device EVM key via BmoniEmbeddedSdk...';
    });

    try {
      // 1. Client-side wallet provisioning via bmoni_embedded_sdk
      final ownerAddress = await WalletService.getOrInitWallet();
      setState(() {
        _statusMessage = 'Device key ready ($ownerAddress). Connecting to BMONI API...';
      });

      // 2. Call backend to create BMONI user, submit KYC persona, and create managed wallet
      final result = await ApiService.onboardUser(
        name: _nameController.text.trim(),
        businessName: _businessController.text.trim(),
        email: _emailController.text.trim(),
        ownerAddress: ownerAddress,
      );

      if (result['success'] == true) {
        setState(() {
          _statusMessage = 'BMONI Smart Wallet provisioned successfully!';
        });
        await Future.delayed(const Duration(milliseconds: 600));
        widget.onOnboarded();
      } else {
        throw Exception(result['error'] ?? 'Onboarding failed');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
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
                        size: 48,
                        color: Color(0xFFB368F7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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
                    'Automated Business Payment Scheduling',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF8B949E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7526C9).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF7526C9).withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, size: 14, color: Color(0xFFB368F7)),
                          SizedBox(width: 6),
                          Text(
                            'Powered by BMONI Embedded Wallet',
                            style: TextStyle(
                              color: Color(0xFFB368F7),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Business Input Card
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
                          'Business Setup',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Uses BMONI sandbox persona for instant KYC & NGN Virtual Account creation.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF8B949E)),
                        ),
                        const SizedBox(height: 20),

                        // Owner Name
                        const Text('Owner Name', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0D1117),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                            hintText: 'e.g. Bunch Dillon',
                            hintStyle: const TextStyle(color: Color(0xFF484F58)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Business Name
                        const Text('Business Name', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _businessController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0D1117),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                            hintText: 'e.g. PayPilot Global Ltd',
                            hintStyle: const TextStyle(color: Color(0xFF484F58)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Email
                        const Text('Email Address', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0D1117),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                            hintText: 'e.g. bunch.dillon@example.com',
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

                  if (_statusMessage != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB368F7))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: const TextStyle(color: Color(0xFFB368F7), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Create Wallet CTA
                  ElevatedButton(
                    onPressed: _isLoading ? null : _createWallet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7526C9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _isLoading
                      ? const Text('Provisioning BMONI Wallet...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, size: 20),
                            SizedBox(width: 8),
                            Text('Create Business Wallet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
