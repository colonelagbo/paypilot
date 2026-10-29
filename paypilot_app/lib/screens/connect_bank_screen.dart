import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class ConnectBankScreen extends StatefulWidget {
  final VoidCallback onBankConnected;
  final bool isInitialSetup;

  const ConnectBankScreen({
    super.key,
    required this.onBankConnected,
    this.isInitialSetup = false,
  });

  @override
  State<ConnectBankScreen> createState() => _ConnectBankScreenState();
}

class _ConnectBankScreenState extends State<ConnectBankScreen> {
  final _accountNumberController = TextEditingController(text: '0123456789');
  final _accountNameController = TextEditingController(text: 'Acme Enterprise Solutions');
  final _customBankController = TextEditingController();
  final _balanceController = TextEditingController(text: '500000');

  List<dynamic> _banks = [];
  String _selectedBankName = 'Guaranty Trust Bank (GTBank)';
  String _selectedBankCode = '058';
  String _selectedAccountType = 'Corporate Current';

  bool _isCustomBank = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  Future<void> _loadBanks() async {
    try {
      final list = await ApiService.getBanks();
      if (mounted) {
        setState(() {
          _banks = list;
          if (_banks.isNotEmpty) {
            _selectedBankName = _banks.first['bankName'];
            _selectedBankCode = _banks.first['bankCode'];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _connectBank() async {
    final accNum = _accountNumberController.text.trim();
    final accName = _accountNameController.text.trim();
    final bankName = _isCustomBank ? _customBankController.text.trim() : _selectedBankName;
    final balance = double.tryParse(_balanceController.text.trim()) ?? 250000.0;

    if (bankName.isEmpty) {
      setState(() => _errorMessage = 'Please enter or select a bank name.');
      return;
    }
    if (accNum.length < 8) {
      setState(() => _errorMessage = 'Please enter a valid bank account number (at least 8-10 digits).');
      return;
    }
    if (accName.isEmpty) {
      setState(() => _errorMessage = 'Please enter the account name.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.connectBankAccount(
        bankName: bankName,
        bankCode: _selectedBankCode,
        accountNumber: accNum,
        accountName: accName,
        accountType: _selectedAccountType,
        initialBalance: balance,
      );

      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully connected $bankName account!'),
              backgroundColor: const Color(0xFF2EA043),
            ),
          );
          widget.onBankConnected();
          if (!widget.isInitialSetup && Navigator.canPop(context)) {
            Navigator.pop(context, true);
          }
        }
      } else {
        throw Exception(res['error'] ?? 'Failed to connect bank account');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon Header
              Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF238636).withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF2EA043), width: 2),
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    size: 44,
                    color: Color(0xFF3FB950),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.isInitialSetup ? 'Connect Your Bank Account' : 'Connect New Bank Account',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Connect an account from any bank to fund and schedule transfers, supplier payouts, and staff payroll.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF8B949E)),
              ),
              const SizedBox(height: 28),

              // Form Container
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bank Selector
                    const Text('Bank Name', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    if (_isLoading)
                      const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)))
                    else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1117),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF30363D)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _isCustomBank ? 'Other / Custom Bank' : _selectedBankName,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF161B22),
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF8B949E)),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            items: [
                              ..._banks.map((b) => DropdownMenuItem<String>(
                                    value: b['bankName'].toString(),
                                    child: Text(b['bankName'].toString()),
                                  )),
                              if (!_banks.any((b) => b['bankName'] == 'Other / Custom Bank'))
                                const DropdownMenuItem<String>(
                                  value: 'Other / Custom Bank',
                                  child: Text('➕ Other / Custom Bank (Any Bank)'),
                                ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  if (val == 'Other / Custom Bank') {
                                    _isCustomBank = true;
                                    _selectedBankName = 'Other Bank';
                                    _selectedBankCode = '000';
                                  } else {
                                    _isCustomBank = false;
                                    _selectedBankName = val;
                                    final found = _banks.firstWhere((b) => b['bankName'] == val, orElse: () => null);
                                    if (found != null) {
                                      _selectedBankCode = found['bankCode'] ?? '000';
                                    }
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      if (_isCustomBank) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _customBankController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0D1117),
                            hintText: 'Enter bank name (e.g. Chase, Barclays, Heritage)',
                            hintStyle: const TextStyle(color: Color(0xFF484F58)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 18),

                    // Account Number
                    const Text('Account Number', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _accountNumberController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(color: Colors.white, letterSpacing: 1.2),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF0D1117),
                        hintText: '10-digit Account Number',
                        hintStyle: const TextStyle(color: Color(0xFF484F58)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check_circle_outline, color: Color(0xFF3FB950), size: 20),
                          tooltip: 'Resolve Name',
                          onPressed: () async {
                            final res = await ApiService.resolveAccount(
                              bankCode: _selectedBankCode,
                              accountNumber: _accountNumberController.text.trim(),
                            );
                            if (res['accountName'] != null) {
                              _accountNameController.text = res['accountName'];
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Account Holder Name
                    const Text('Account Holder / Business Name', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _accountNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF0D1117),
                        hintText: 'Account Holder Name',
                        hintStyle: const TextStyle(color: Color(0xFF484F58)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Account Type & Starting Balance Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Account Type', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D1117),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF30363D)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedAccountType,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF161B22),
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    items: const [
                                      DropdownMenuItem(value: 'Corporate Current', child: Text('Corporate Current')),
                                      DropdownMenuItem(value: 'Business Savings', child: Text('Business Savings')),
                                      DropdownMenuItem(value: 'Checking', child: Text('Checking')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedAccountType = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Available Balance (₦)', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _balanceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF0D1117),
                                  hintText: '500,000',
                                  hintStyle: const TextStyle(color: Color(0xFF484F58)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFFF7B72), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFFF7B72), fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 26),

              // Connect CTA Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _connectBank,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          SizedBox(width: 10),
                          Text('Connecting Bank Account...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.link_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Connect Bank Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.isInitialSetup) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        body: SafeArea(child: content),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Connect Bank Account'),
        backgroundColor: const Color(0xFF161B22),
      ),
      body: SafeArea(child: content),
    );
  }
}
