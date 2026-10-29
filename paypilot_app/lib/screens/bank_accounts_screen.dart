import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'connect_bank_screen.dart';

class BankAccountsScreen extends StatefulWidget {
  const BankAccountsScreen({super.key});

  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  List<dynamic> _bankAccounts = [];
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  Timer? _autoRefreshTimer;

  final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦');

  @override
  void initState() {
    super.initState();
    _loadData();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) => _loadData(silent: true));
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final accounts = await ApiService.getBankAccounts();
      final txs = await ApiService.getTransactions();
      if (mounted) {
        setState(() {
          _bankAccounts = accounts;
          _transactions = txs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _setPrimary(String bankAccountId, String bankName) async {
    try {
      await ApiService.setPrimaryBankAccount(bankAccountId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$bankName set as primary account'), backgroundColor: const Color(0xFF2EA043)),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _disconnectAccount(Map<String, dynamic> account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF30363D))),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF7B72)),
            SizedBox(width: 8),
            Text('Disconnect Bank Account?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Disconnect ${account['bank_name']} (${account['account_number']})? Scheduled payments funded from this account will need another connected account.',
          style: const TextStyle(color: Color(0xFFC9D1D9), fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Color(0xFF8B949E)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDA3633), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ApiService.disconnectBankAccount(account['id'].toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Disconnected ${account['bank_name']} account')),
        );
        _loadData();
      }
    }
  }

  Future<void> _showTopUpDialog(Map<String, dynamic> account) async {
    final controller = TextEditingController(text: '100000');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF30363D))),
        title: Row(
          children: [
            const Icon(Icons.add_card_rounded, color: Color(0xFF2EA043)),
            const SizedBox(width: 8),
            Text('Top Up ${account['bank_name']}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account: ${account['account_number']} (${account['account_type']})', style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13)),
            const SizedBox(height: 14),
            const Text('Amount to Deposit (₦)', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: '₦ ',
                prefixStyle: const TextStyle(color: Color(0xFF2EA043), fontSize: 18, fontWeight: FontWeight.bold),
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
              await ApiService.fundBankAccount(account['id'].toString(), amt);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deposited ${currencyFormat.format(amt)} to ${account['bank_name']}!'),
                    backgroundColor: const Color(0xFF2EA043),
                  ),
                );
                _loadData();
              }
            },
            child: const Text('Deposit Funds'),
          ),
        ],
      ),
    );
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Connected Bank Accounts', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF161B22),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF8B949E)),
            tooltip: 'Refresh Accounts',
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF3FB950)),
            tooltip: 'Connect Bank Account',
            onPressed: _openConnectScreen,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3FB950)))
          : RefreshIndicator(
              onRefresh: () => _loadData(),
              color: const Color(0xFF3FB950),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Bank Accounts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                            SizedBox(height: 2),
                            Text('Connected accounts available for automated payouts', style: TextStyle(color: Color(0xFF8B949E), fontSize: 13)),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _openConnectScreen,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Connect Bank'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF238636),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    if (_bankAccounts.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B22),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF30363D)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.account_balance_outlined, size: 48, color: Color(0xFF8B949E)),
                            const SizedBox(height: 14),
                            const Text(
                              'No Bank Account Connected Yet',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Connect an account from any bank to fund and schedule payments.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              onPressed: _openConnectScreen,
                              icon: const Icon(Icons.link_rounded),
                              label: const Text('Connect an Account Now'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF238636),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Bank Account Cards
                      ..._bankAccounts.map((account) {
                        final isPrimary = account['is_primary'] == 1;
                        final balance = (account['balance'] as num?)?.toDouble() ?? 0.0;
                        final bankName = account['bank_name'] ?? 'Bank';
                        final accNum = account['account_number'] ?? '0000000000';
                        final maskedNum = accNum.length > 4
                            ? '•••• •••• •••• ${accNum.substring(accNum.length - 4)}'
                            : accNum;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: isPrimary
                                ? const LinearGradient(
                                    colors: [Color(0xFF1C2B1D), Color(0xFF131D14)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isPrimary ? null : const Color(0xFF161B22),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isPrimary ? const Color(0xFF2EA043) : const Color(0xFF30363D),
                              width: isPrimary ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Bar: Bank Name & Badges
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isPrimary ? const Color(0xFF2EA043).withOpacity(0.2) : const Color(0xFF30363D),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.account_balance_rounded,
                                          size: 20,
                                          color: isPrimary ? const Color(0xFF3FB950) : const Color(0xFF8B949E),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            bankName,
                                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            account['account_type'] ?? 'Corporate Account',
                                            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (isPrimary)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF238636).withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFF2EA043)),
                                      ),
                                      child: const Text(
                                        'PRIMARY',
                                        style: TextStyle(color: Color(0xFF3FB950), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 18),

                              // Account Number & Copy
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Account Number', style: TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
                                      const SizedBox(height: 2),
                                      Text(
                                        maskedNum,
                                        style: const TextStyle(color: Color(0xFFC9D1D9), fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF8B949E)),
                                    tooltip: 'Copy Account Number',
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: accNum));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Account number copied to clipboard!')),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Balance & Actions
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Available Balance', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                                      const SizedBox(height: 2),
                                      Text(
                                        currencyFormat.format(balance),
                                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _showTopUpDialog(account),
                                        icon: const Icon(Icons.add, size: 14),
                                        label: const Text('Top Up'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF3FB950),
                                          side: const BorderSide(color: Color(0xFF2EA043)),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, color: Color(0xFF8B949E)),
                                        color: const Color(0xFF161B22),
                                        onSelected: (val) {
                                          if (val == 'primary') {
                                            _setPrimary(account['id'].toString(), bankName);
                                          } else if (val == 'disconnect') {
                                            _disconnectAccount(account);
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          if (!isPrimary)
                                            const PopupMenuItem(
                                              value: 'primary',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.star_outline, size: 18, color: Color(0xFF3FB950)),
                                                  SizedBox(width: 8),
                                                  Text('Set as Primary', style: TextStyle(color: Colors.white)),
                                                ],
                                              ),
                                            ),
                                          const PopupMenuItem(
                                            value: 'disconnect',
                                            child: Row(
                                              children: [
                                                Icon(Icons.link_off, size: 18, color: Color(0xFFFF7B72)),
                                                SizedBox(width: 8),
                                                Text('Disconnect Account', style: TextStyle(color: Color(0xFFFF7B72))),
                                              ],
                                            ),
                                          ),
                                        ],
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

                    const SizedBox(height: 24),

                    // Recent Bank Settlements
                    const Text('Recent Bank Transfer Settlements', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    const Text('Completed transfers executed from your connected bank accounts.', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                    const SizedBox(height: 14),

                    if (_transactions.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B22),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF30363D)),
                        ),
                        child: const Center(
                          child: Text(
                            'No settled transfers yet. Completed payouts will appear here.',
                            style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ..._transactions.map((tx) {
                        final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                        final dateStr = tx['created_at'] != null
                            ? DateFormat('MMM dd, yyyy • HH:mm').format(DateTime.tryParse(tx['created_at']) ?? DateTime.now())
                            : '';

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
                                  color: const Color(0xFF2EA043).withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFF3FB950), size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx['recipient_name'] ?? 'Recipient',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'From: ${tx['source_bank'] ?? 'Bank Account'} • Ref: ${tx['reference'] ?? ''}',
                                      style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                                    ),
                                    Text(
                                      dateStr,
                                      style: const TextStyle(color: Color(0xFF484F58), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '- ${currencyFormat.format(amt)}',
                                style: const TextStyle(color: Color(0xFFFF7B72), fontWeight: FontWeight.bold, fontSize: 14),
                              ),
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
