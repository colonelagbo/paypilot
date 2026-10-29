import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'connect_bank_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToSmartCheck;
  final VoidCallback onNavigateToSchedule;
  final VoidCallback onNavigateToBankAccounts;

  const HomeScreen({
    super.key,
    required this.onNavigateToSmartCheck,
    required this.onNavigateToSchedule,
    required this.onNavigateToBankAccounts,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _primaryBankAccount;
  List<dynamic> _bankAccounts = [];
  Map<String, dynamic>? _smartCheck;
  List<dynamic> _payments = [];
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  bool _isRunningScheduler = false;
  Timer? _autoRefreshTimer;

  final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦');

  @override
  void initState() {
    super.initState();
    _loadData();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _loadData(silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final userRes = await ApiService.getCurrentUser();
      final accountsRes = await ApiService.getBankAccounts();
      final smartRes = await ApiService.getSmartCheck();
      final paymentsRes = await ApiService.getPayments();
      final txsRes = await ApiService.getTransactions();

      if (mounted) {
        setState(() {
          _user = userRes['user'];
          _bankAccounts = accountsRes;
          _primaryBankAccount = accountsRes.firstWhere(
            (b) => b['is_primary'] == 1,
            orElse: () => accountsRes.isNotEmpty ? accountsRes.first : null,
          );
          _smartCheck = smartRes;
          _payments = paymentsRes;
          _transactions = txsRes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showTopUpDialog() async {
    if (_primaryBankAccount == null) {
      _openConnectScreen();
      return;
    }

    final controller = TextEditingController(text: '50000');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
        title: Row(
          children: [
            const Icon(Icons.add_card_rounded, color: Color(0xFF3FB950)),
            const SizedBox(width: 8),
            Text('Deposit to ${_primaryBankAccount!['bank_name']}', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account: ${_primaryBankAccount!['account_number']}',
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
            ),
            const SizedBox(height: 14),
            const Text('Amount to Deposit (₦)', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: '₦ ',
                prefixStyle: const TextStyle(color: Color(0xFF3FB950), fontSize: 18, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: const Color(0xFF0D1117),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF8B949E)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636), foregroundColor: Colors.white),
            onPressed: () async {
              final amt = double.tryParse(controller.text.trim()) ?? 50000;
              Navigator.pop(ctx);
              await ApiService.fundBankAccount(_primaryBankAccount!['id'].toString(), amt);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Successfully added ${currencyFormat.format(amt)}!'),
                    backgroundColor: const Color(0xFF2EA043),
                  ),
                );
                _loadData();
              }
            },
            child: const Text('Deposit'),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerSchedulerNow() async {
    setState(() => _isRunningScheduler = true);
    try {
      final res = await ApiService.runSchedulerNow();
      if (mounted) {
        final processed = res['processed'] ?? 0;
        final msg = res['message'] ?? (processed > 0 ? 'Executed $processed scheduled transfer(s)!' : 'Scheduler ran: no due payments.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: const Color(0xFF238636)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scheduler execution error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRunningScheduler = false);
        _loadData();
      }
    }
  }

  void _openConnectScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConnectBankScreen(
          onBankConnected: () => _loadData(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bankName = _primaryBankAccount?['bank_name'] ?? 'No Bank Connected';
    final accNum = _primaryBankAccount?['account_number'] ?? '';
    final maskedNum = accNum.length > 4 ? '•••• ${accNum.substring(accNum.length - 4)}' : accNum;
    final balance = (_primaryBankAccount?['balance'] as num?)?.toDouble() ?? 0.0;
    final hasBank = _primaryBankAccount != null;

    final isShortfall = (_smartCheck?['shortfall'] ?? 0.0) > 0;
    final isReady = _smartCheck?['isReady'] == true;
    final shortfallAmt = (_smartCheck?['shortfall'] ?? 0.0) as num;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF7526C9).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFFB368F7), size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PayPilot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  _user?['business_name'] ?? 'Business Account',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E), fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF8B949E)),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7526C9)))
          : RefreshIndicator(
              onRefresh: () => _loadData(),
              color: const Color(0xFF7526C9),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Primary Connected Bank Card
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: hasBank
                            ? const LinearGradient(
                                colors: [Color(0xFF1B2C1F), Color(0xFF121B13)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: hasBank ? null : const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: hasBank ? const Color(0xFF2EA043).withOpacity(0.6) : const Color(0xFF30363D),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF238636).withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.account_balance_rounded, color: Color(0xFF3FB950), size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hasBank ? bankName : 'Connect a Bank Account',
                                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      if (hasBank)
                                        Text(
                                          'Acct: $maskedNum • ${_primaryBankAccount!['account_type'] ?? 'Corporate'}',
                                          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              if (hasBank)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF238636).withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF2EA043)),
                                  ),
                                  child: const Text('PRIMARY', style: TextStyle(color: Color(0xFF3FB950), fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (hasBank) ...[
                            const Text('Available Balance', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              currencyFormat.format(balance),
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _showTopUpDialog,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Top Up'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF238636),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton.icon(
                                  onPressed: widget.onNavigateToBankAccounts,
                                  icon: const Icon(Icons.account_balance_outlined, size: 16),
                                  label: Text('All Accounts (${_bankAccounts.length})'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFC9D1D9),
                                    side: const BorderSide(color: Color(0xFF30363D)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            const Text(
                              'Connect an account from any bank to fund and schedule transfers, supplier payouts, and staff payroll.',
                              style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _openConnectScreen,
                              icon: const Icon(Icons.link_rounded),
                              label: const Text('Connect Bank Account'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF238636),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Smart Pay Balance Verification Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isShortfall
                            ? const Color(0xFF3A1C16)
                            : isReady
                                ? const Color(0xFF132819)
                                : const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isShortfall
                              ? const Color(0xFFD29922)
                              : isReady
                                  ? const Color(0xFF2EA043)
                                  : const Color(0xFF30363D),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isShortfall
                                ? Icons.warning_amber_rounded
                                : isReady
                                    ? Icons.check_circle_rounded
                                    : Icons.info_outline_rounded,
                            color: isShortfall
                                ? const Color(0xFFE3B341)
                                : isReady
                                    ? const Color(0xFF3FB950)
                                    : const Color(0xFF8B949E),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isShortfall
                                      ? '⚠️ Payment Shortfall Alert'
                                      : isReady
                                          ? '✓ Smart Pay: Ready to Execute'
                                          : 'Smart Pay Status',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isShortfall
                                        ? const Color(0xFFF2CC60)
                                        : isReady
                                            ? const Color(0xFF56D364)
                                            : Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isShortfall
                                      ? 'Shortfall of ${currencyFormat.format(shortfallAmt)} on your connected bank account.'
                                      : isReady
                                          ? 'Connected bank balance covers all upcoming scheduled transfers.'
                                          : 'No transfers currently scheduled for execution.',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFFC9D1D9)),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: widget.onNavigateToSmartCheck,
                            child: const Text('View', style: TextStyle(color: Color(0xFFB368F7), fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // 3. Quick Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: widget.onNavigateToSchedule,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161B22),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF30363D)),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.send_rounded, color: Color(0xFFB368F7), size: 24),
                                  SizedBox(height: 8),
                                  Text('Schedule Payout', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: widget.onNavigateToBankAccounts,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161B22),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF30363D)),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.account_balance_rounded, color: Color(0xFF3FB950), size: 24),
                                  SizedBox(height: 8),
                                  Text('Bank Accounts', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: _isRunningScheduler ? null : _triggerSchedulerNow,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161B22),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF30363D)),
                              ),
                              child: Column(
                                children: [
                                  _isRunningScheduler
                                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF58A6FF)))
                                      : const Icon(Icons.play_circle_outline_rounded, color: Color(0xFF58A6FF), size: 24),
                                  const SizedBox(height: 8),
                                  const Text('Run Scheduler', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),

                    // 4. Upcoming Scheduled Payments
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Scheduled Payments & Payroll', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: widget.onNavigateToSchedule,
                          child: const Text('Add Payment', style: TextStyle(color: Color(0xFFB368F7), fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_payments.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B22),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF30363D)),
                        ),
                        child: const Center(
                          child: Text(
                            'No scheduled payments yet. Tap "Add Payment" to schedule a single payment or payroll batch.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ..._payments.take(5).map((payment) {
                        final amt = (payment['amount'] as num?)?.toDouble() ?? 0.0;
                        final status = payment['status'] ?? 'SCHEDULED';
                        final isDone = status == 'SUCCESSFUL';
                        final isFailed = status == 'INSUFFICIENT_FUNDS' || status == 'FAILED';

                        Color badgeColor = const Color(0xFF58A6FF);
                        if (isDone) badgeColor = const Color(0xFF3FB950);
                        if (isFailed) badgeColor = const Color(0xFFFF7B72);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161B22),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF30363D)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: badgeColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  payment['payment_type'] == 'PAYROLL' ? Icons.groups_rounded : Icons.person_rounded,
                                  color: badgeColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      payment['recipient_name'] ?? 'Recipient',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'To: ${payment['bank_name'] ?? 'Bank'} (${payment['account_number'] ?? ''})',
                                      style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                                    ),
                                    Text(
                                      'Due: ${payment['payment_date']} at ${payment['payment_time'] ?? '09:00'}',
                                      style: const TextStyle(color: Color(0xFF484F58), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currencyFormat.format(amt),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 26),

                    // 5. Recent Bank Settlements
                    const Text('Recent Bank Transfer Settlements', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    if (_transactions.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B22),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF30363D)),
                        ),
                        child: const Center(
                          child: Text('No completed bank transfers yet.', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                        ),
                      )
                    else
                      ..._transactions.take(4).map((tx) {
                        final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161B22),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF30363D)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tx['recipient_name'] ?? 'Recipient', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text('Ref: ${tx['reference'] ?? ''} • Via: ${tx['source_bank'] ?? 'Bank'}', style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
                                ],
                              ),
                              Text('- ${currencyFormat.format(amt)}', style: const TextStyle(color: Color(0xFFFF7B72), fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }
}
