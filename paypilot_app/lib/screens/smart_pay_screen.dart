import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class SmartPayScreen extends StatefulWidget {
  final VoidCallback onFundWalletTapped;

  const SmartPayScreen({super.key, required this.onFundWalletTapped});

  @override
  State<SmartPayScreen> createState() => _SmartPayScreenState();
}

class _SmartPayScreenState extends State<SmartPayScreen> {
  Map<String, dynamic>? _smartCheck;
  bool _isLoading = true;
  bool _isExecuting = false;

  final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getSmartCheck();
      if (mounted) {
        setState(() {
          _smartCheck = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _executePaymentsNow() async {
    setState(() => _isExecuting = true);
    try {
      final result = await ApiService.runSchedulerNow();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Executed due payments via BMONI!'),
            backgroundColor: const Color(0xFF7526C9),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Execution error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExecuting = false);
        _loadData();
      }
    }
  }

  Future<void> _deletePayment(Map<String, dynamic> payment) async {
    final id = payment['id'].toString();
    final name = payment['recipient_name'] ?? 'Recipient';
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
          'Cancel and delete payment of ${currencyFormat.format(amount)} to $name?',
          style: const TextStyle(color: Color(0xFFC9D1D9), fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep', style: TextStyle(color: Color(0xFF8B949E)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDA3633), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await ApiService.deletePayment(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Payment deleted!'), backgroundColor: const Color(0xFF3FB950)),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
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

    final balance = (_smartCheck?['currentBalance'] ?? 0.0) as num;
    final totalDue = (_smartCheck?['totalDue'] ?? 0.0) as num;
    final shortfall = (_smartCheck?['shortfall'] ?? 0.0) as num;
    final isReady = _smartCheck?['isReady'] ?? false;
    final pendingPayments = (_smartCheck?['pendingPayments'] as List?) ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: Color(0xFFB368F7), size: 20),
            SizedBox(width: 8),
            Text('Payment Check / Smart Pay', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFFC9D1D9)), onPressed: _loadData),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFFB368F7),
        child: ListView(
          padding: const EdgeInsets.all(18.0),
          children: [
            // 1. Status Hero Banner (✓ Ready vs ⚠️ Shortfall)
            if (shortfall > 0)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF451A03), Color(0xFF1C1917)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle),
                          child: const Icon(Icons.warning_amber_rounded, color: Colors.black, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            '⚠️ Shortfall Warning',
                            style: TextStyle(color: Color(0xFFFBBF24), fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Payroll may fail — shortfall of ${currencyFormat.format(shortfall)}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your BMONI wallet holds ${currencyFormat.format(balance)}, but scheduled payments require ${currencyFormat.format(totalDue)}. Fund your wallet before the scheduler executes.',
                      style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: widget.onFundWalletTapped,
                      icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                      label: const Text('Fund Wallet Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              )
            else if (isReady)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF064E3B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF10B981).withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                          child: const Icon(Icons.check_rounded, color: Colors.black, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            '✓ Ready to Pay',
                            style: TextStyle(color: Color(0xFF34D399), fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'BMONI Wallet balance covers all scheduled payouts!',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Wallet holds ${currencyFormat.format(balance)}. Total required is ${currencyFormat.format(totalDue)}. All transfers are ready for automated execution.',
                      style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isExecuting ? null : _executePaymentsNow,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: _isExecuting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : const Text('Execute Payments Now via BMONI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF34D399),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.task_alt_rounded, color: Color(0xFF8B949E), size: 40),
                    SizedBox(height: 10),
                    Text('No Payments Pending Execution', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('All scheduled single payments and payroll batches have been processed or none are due today.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8B949E), fontSize: 13)),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // 2. Financial Metrics Comparison Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Balance & Commitment Analysis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 16),
                  _buildMetricRow('Current BMONI Wallet Balance', currencyFormat.format(balance), const Color(0xFF58A6FF)),
                  const Divider(color: Color(0xFF30363D)),
                  _buildMetricRow('Total Amount Due', currencyFormat.format(totalDue), Colors.white),
                  const Divider(color: Color(0xFF30363D)),
                  _buildMetricRow(
                    shortfall > 0 ? 'Projected Shortfall' : 'Surplus Available',
                    shortfall > 0 ? '-${currencyFormat.format(shortfall)}' : '+${currencyFormat.format(balance - totalDue)}',
                    shortfall > 0 ? const Color(0xFFF59E0B) : const Color(0xFF3FB950),
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 3. Pending Payments Breakdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Payments in Queue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text('${pendingPayments.length} Total', style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),

            if (pendingPayments.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: const Center(child: Text('Queue is clear.', style: TextStyle(color: Color(0xFF8B949E)))),
              )
            else
              ...pendingPayments.map((p) {
                final amount = (p['amount'] ?? 0.0) as num;
                final status = p['status'] ?? 'SCHEDULED';
                final isAtRisk = status == 'INSUFFICIENT_FUNDS' || shortfall > 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isAtRisk ? const Color(0xFFF59E0B).withOpacity(0.4) : const Color(0xFF30363D)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isAtRisk ? Icons.error_outline_rounded : Icons.pending_actions_rounded,
                        color: isAtRisk ? const Color(0xFFF59E0B) : const Color(0xFF58A6FF),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['recipient_name'] ?? 'Recipient', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text('${p['bank_name']} • Due: ${p['payment_date']}', style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(currencyFormat.format(amount), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isAtRisk ? const Color(0xFFF59E0B) : const Color(0xFF58A6FF)).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: isAtRisk ? const Color(0xFFF59E0B) : const Color(0xFF58A6FF),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF8B949E)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Delete payment',
                                onPressed: () => _deletePayment(p),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color valueColor, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isBold ? 16 : 14,
          ),
        ),
      ],
    );
  }
}
