import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/wallet_service.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToSmartCheck;
  final VoidCallback onNavigateToSchedule;

  const HomeScreen({
    super.key,
    required this.onNavigateToSmartCheck,
    required this.onNavigateToSchedule,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _wallet;
  Map<String, dynamic>? _smartCheck;
  List<dynamic> _payments = [];
  List<dynamic> _recipients = [];
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  bool _isRunningScheduler = false;
  bool _isFunding = false;
  Timer? _autoRefreshTimer;

  final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦');

  @override
  void initState() {
    super.initState();
    _loadData();
    // Auto-refresh every 6 seconds to keep wallet balance, recipients, and payments live
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
      final walletRes = await ApiService.getWallet();
      final smartRes = await ApiService.getSmartCheck();
      final paymentsRes = await ApiService.getPayments();
      final recsRes = await ApiService.getRecipients();
      final txsRes = await ApiService.getTransactions();

      if (mounted) {
        setState(() {
          _user = userRes['user'];
          _wallet = walletRes;
          _smartCheck = smartRes;
          _payments = paymentsRes;
          _recipients = recsRes;
          _transactions = txsRes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showFundDialog() async {
    setState(() => _isFunding = true);
    try {
      final account = await ApiService.getDepositAccount();
      if (!mounted) return;
      final data = account['data'] is Map ? Map<String,dynamic>.from(account['data']) : account;
      final accountNumber = data['accountNumber'] ?? data['account_number'] ?? '—';
      final accountName = data['accountName'] ?? data['account_name'] ?? '—';
      final bankName = data['bankName'] ?? data['bank_name'] ?? data['bank'] ?? '—';
      await showDialog(context: context, builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Fund BMONI Wallet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SelectableText('''Transfer NGN to this BMONI deposit account.

Bank: $bankName
Account name: $accountName
Account number: $accountNumber

BMONI will credit the wallet as CNGN after the deposit is processed.''', style: const TextStyle(color: Color(0xFFC9D1D9), height: 1.5)),
        actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Done'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to load BMONI funding account: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) { setState(() => _isFunding = false); _loadData(); } }
  }


  Future<void> _deleteScheduledPayment(Map<String, dynamic> payment) async {
    final paymentId = payment['id'].toString();
    final recipientName = payment['recipient_name'] ?? 'Recipient';
    final amount = (payment['amount'] ?? 0.0) as num;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFFF7B72)),
            SizedBox(width: 8),
            Text('Delete Payment?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel and delete the scheduled payment of ${currencyFormat.format(amount)} to $recipientName?',
          style: const TextStyle(color: Color(0xFFC9D1D9), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep', style: TextStyle(color: Color(0xFF8B949E))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDA3633),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Payment'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await ApiService.deletePayment(paymentId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Payment deleted successfully!'),
              backgroundColor: const Color(0xFF3FB950),
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete payment: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _runSchedulerNow() async {
    setState(() => _isRunningScheduler = true);
    try {
      final result = await ApiService.runSchedulerNow();
      final results = (result['results'] as List?) ?? const [];
      final awaiting = results.where((x) => x is Map && x['status'] == 'AWAITING_SIGNATURE').toList();
      if (awaiting.isNotEmpty) {
        for (final item in awaiting) {
          final paymentId = item['id'].toString();
          final prepared = await ApiService.preparePaymentSignature(paymentId);
          final signature = await WalletService.signDigest(prepared['signingPayloadHash'].toString());
          await ApiService.submitPaymentSignature(paymentId, signature);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(awaiting.isNotEmpty ? 'BMONI payment signed and submitted.' : (result['message'] ?? 'Scheduler completed successfully!')),
            backgroundColor: const Color(0xFF7526C9),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scheduler error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRunningScheduler = false);
        _loadData();
      }
    }
  }

  Color _getCategoryColor(String cat) {
    switch (cat.toUpperCase()) {
      case 'SUPPLIER':
        return const Color(0xFF58A6FF);
      case 'OTHER':
        return const Color(0xFFE3B341);
      case 'STAFF':
      default:
        return const Color(0xFFB368F7);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1117),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFB368F7))),
      );
    }

    final totalBalance = (_wallet?['totalBalance'] ?? 0.0) as num;
    final onchainBalance = (_wallet?['onchainBalance'] ?? 0.0) as num;
    final address = _wallet?['walletAddress'] ?? '0x...';
    final shortfall = (_smartCheck?['shortfall'] ?? 0.0) as num;
    final isShortfall = shortfall > 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _user?['business_name'] ?? 'PayPilot Business',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const Text(
              'Automated Payment Scheduling',
              style: TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFC9D1D9)),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFFB368F7),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 1. Comprehensive BMONI Wallet Hero Card on Home
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B0764), Color(0xFF161B22)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF7526C9).withOpacity(0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF7526C9).withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7526C9).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFB368F7).withOpacity(0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined, size: 13, color: Color(0xFFB368F7)),
                            SizedBox(width: 5),
                            Text(
                              'Powered by BMONI',
                              style: TextStyle(color: Color(0xFFB368F7), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isFunding ? null : _showFundDialog,
                        icon: const Icon(Icons.add_circle_outline, size: 14),
                        label: const Text('Fund Wallet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7526C9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Total BMONI Balance', style: TextStyle(color: Color(0xFFD8B4FE), fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    currencyFormat.format(totalBalance),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Balance Breakdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'On-chain: ${currencyFormat.format(onchainBalance)}',
                        style: const TextStyle(color: Color(0xFFC084FC), fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'BMONI CNGN',
                        style: const TextStyle(color: Color(0xFFC084FC), fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Address with Copy
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, size: 14, color: Color(0xFFB368F7)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(color: Color(0xFFE9D5FF), fontSize: 11, fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFFB368F7)),
                          tooltip: 'Copy address',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: address));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Wallet address copied!'), duration: Duration(seconds: 1)),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Smart Pay Alert Banner
            InkWell(
              onTap: widget.onNavigateToSmartCheck,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isShortfall ? const Color(0xFFD29922).withOpacity(0.15) : const Color(0xFF3FB950).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isShortfall ? const Color(0xFFD29922).withOpacity(0.4) : const Color(0xFF3FB950).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isShortfall ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                      color: isShortfall ? const Color(0xFFE3B341) : const Color(0xFF3FB950),
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isShortfall ? 'Smart Pay Alert: Shortfall Detected' : 'Smart Pay Balance Check: Ready',
                            style: TextStyle(
                              color: isShortfall ? const Color(0xFFE3B341) : const Color(0xFF3FB950),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isShortfall
                                ? 'Payment may fail — shortfall of ${currencyFormat.format(shortfall)} — Tap to Fund Wallet'
                                : 'All scheduled payments are fully covered by current BMONI balance.',
                            style: TextStyle(
                              color: isShortfall ? Colors.orange.shade200 : Colors.green.shade200,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF8B949E)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 3. Quick Action Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF21262D),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF30363D)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: widget.onNavigateToSmartCheck,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_outlined, size: 16, color: Color(0xFFB368F7)),
                        SizedBox(width: 6),
                        Text('Smart Pay Check', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7526C9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isRunningScheduler ? null : _runSchedulerNow,
                    child: _isRunningScheduler
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded, size: 18),
                              SizedBox(width: 4),
                              Text('Run Scheduler', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 4. Registered Payees & Staff
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Payees & Staff',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  '${_recipients.length} Registered',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_recipients.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: const Text('No recipients added yet. Add payees from Schedule tab.', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
              )
            else
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recipients.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (ctx, idx) {
                    final rec = _recipients[idx];
                    final name = rec['name'] ?? 'Payee';
                    final bank = rec['bank_name'] ?? '';
                    final acct = rec['account_number'] ?? '';
                    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                    final cat = (rec['category'] ?? 'STAFF').toString().toUpperCase();

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF30363D)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: _getCategoryColor(cat).withOpacity(0.2),
                            child: Text(initial, style: TextStyle(color: _getCategoryColor(cat), fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _getCategoryColor(cat).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: _getCategoryColor(cat).withOpacity(0.4)),
                                    ),
                                    child: Text(
                                      cat,
                                      style: TextStyle(color: _getCategoryColor(cat), fontSize: 8, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text('$bank ($acct)', style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),

            // 5. Upcoming Payments Header with Add Shortcut
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Upcoming Payments',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                TextButton.icon(
                  onPressed: widget.onNavigateToSchedule,
                  icon: const Icon(Icons.add, size: 16, color: Color(0xFFB368F7)),
                  label: const Text('Schedule', style: TextStyle(color: Color(0xFFB368F7), fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 6. Scheduled Payments List (With Delete Option)
            if (_payments.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 40, color: Color(0xFF484F58)),
                    SizedBox(height: 12),
                    Text(
                      'No Scheduled Payments',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Use Schedule Payment to automate transfers.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ..._payments.map((payment) {
                final amount = (payment['amount'] ?? 0.0) as num;
                final status = payment['status'] ?? 'SCHEDULED';
                final isPayroll = payment['payment_type'] == 'PAYROLL';
                final isFailedOrShortfall = status == 'INSUFFICIENT_FUNDS' || status == 'FAILED';
                final isSuccess = status == 'SUCCESSFUL';
                final payeeCategory = (payment['recipient_category'] ?? 'STAFF').toString().toUpperCase();

                Color badgeColor = const Color(0xFF58A6FF);
                if (isSuccess) badgeColor = const Color(0xFF3FB950);
                if (isFailedOrShortfall) badgeColor = const Color(0xFFD29922);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isFailedOrShortfall ? const Color(0xFFD29922).withOpacity(0.5) : const Color(0xFF30363D),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isPayroll ? const Color(0xFF7526C9).withOpacity(0.2) : const Color(0xFF58A6FF).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isPayroll ? Icons.groups_rounded : Icons.person_outline_rounded,
                          color: isPayroll ? const Color(0xFFB368F7) : const Color(0xFF58A6FF),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  payment['recipient_name'] ?? 'Recipient',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(payeeCategory).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: _getCategoryColor(payeeCategory).withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    payeeCategory,
                                    style: TextStyle(color: _getCategoryColor(payeeCategory), fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${payment['bank_name'] ?? ''} • Due: ${payment['payment_date']} ${payment['payment_time'] ?? ''}',
                              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                            ),
                            if (payment['bmoni_reference'] != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Ref: ${payment['bmoni_reference']}',
                                style: const TextStyle(color: Color(0xFFB368F7), fontSize: 11, fontFamily: 'monospace'),
                              ),
                            ],
                            if (status == 'AWAITING_SIGNATURE') ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  try {
                                    final prepared = await ApiService.preparePaymentSignature(payment['id'].toString());
                                    final signature = await WalletService.signDigest(prepared['signingPayloadHash'].toString());
                                    await ApiService.submitPaymentSignature(payment['id'].toString(), signature);
                                    await _loadData();
                                  } catch (e) {
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment signature failed: $e'), backgroundColor: Colors.red));
                                  }
                                },
                                icon: const Icon(Icons.lock_open_rounded, size: 14),
                                label: const Text('Sign & Pay', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currencyFormat.format(amount),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: badgeColor.withOpacity(0.4)),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Delete Button for scheduled payments
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF8B949E)),
                                tooltip: 'Delete payment',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _deleteScheduledPayment(payment),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 28),

            // 7. Recent BMONI Settlements / Transactions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent BMONI Settlements',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  '${_transactions.length} Settled',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_transactions.isEmpty)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: const Center(
                  child: Text(
                    'No settled transactions yet. Completed transfers will show BMONI references here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                  ),
                ),
              )
            else
              ..._transactions.take(5).map((tx) {
                final amount = (tx['amount'] ?? 0.0) as num;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3FB950).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.check_circle_outline, color: Color(0xFF3FB950), size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx['recipient_name'] ?? 'Recipient',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              tx['bmoni_reference'] ?? 'BMONI Transfer',
                              style: const TextStyle(color: Color(0xFFB368F7), fontSize: 11, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '-${currencyFormat.format(amount)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
