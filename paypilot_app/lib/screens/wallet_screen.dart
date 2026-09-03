import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Map<String, dynamic>? _wallet;
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  bool _isFunding = false;

  final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final walletRes = await ApiService.getWallet();
      final txsRes = await ApiService.getTransactions();
      if (mounted) {
        setState(() {
          _wallet = walletRes;
          _transactions = txsRes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
        content: SelectableText('Transfer NGN to this BMONI deposit account.\n\nBank: $bankName\nAccount name: $accountName\nAccount number: $accountNumber\n\nBMONI will credit the wallet as CNGN after the deposit is processed.', style: const TextStyle(color: Color(0xFFC9D1D9), height: 1.5)),
        actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Done'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to load BMONI funding account: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) { setState(() => _isFunding = false); _loadData(); } }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1117),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFB368F7))),
      );
    }

    final totalBalance = (_wallet?['balance'] ?? 0.0) as num;
    final address = _wallet?['walletAddress'] ?? '0x...';
    final bmoniWalletId = _wallet?['bmoniWalletId'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('BMONI Wallet', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFFC9D1D9)), onPressed: _loadData),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFFB368F7),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 1. Embedded Wallet Primary Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B0764), Color(0xFF1E1B4B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF7526C9).withOpacity(0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF7526C9).withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 13, color: Color(0xFFB368F7)),
                            SizedBox(width: 5),
                            Text(
                              'Powered by BMONI',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3FB950).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF3FB950).withOpacity(0.4)),
                        ),
                        child: const Text('Active', style: TextStyle(color: Color(0xFF3FB950), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Total Wallet Balance', style: TextStyle(color: Color(0xFFD8B4FE), fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    currencyFormat.format(totalBalance),
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: Color(0xFF4C1D95)),
                  const SizedBox(height: 12),

                  const SizedBox(height: 16),

                  // Smart Account Address
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Color(0xFFB368F7)),
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

            // 2. Fund Wallet CTA
            ElevatedButton(
              onPressed: _isFunding ? null : _showFundDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7526C9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isFunding
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Fund Wallet via BMONI', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
            const SizedBox(height: 28),

            // 3. BMONI Infrastructure Metadata Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BMONI Infrastructure Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  _buildDetailRow('Wallet ID', bmoniWalletId.isNotEmpty ? bmoniWalletId : 'Managed Smart Account'),
                  _buildDetailRow('Currency Token', 'CNGN (Nigerian Naira Stablecoin)'),
                  _buildDetailRow('Blockchain', 'Base Sepolia (EVM Safe / ERC-4337)'),
                  _buildDetailRow('Signing Mode', 'secp256k1 Low-S Normalised (EIP-2)'),
                  _buildDetailRow('KMS Co-Signer', 'BMONI KMS Multi-Sig Relay'),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 4. Transaction History Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Transaction History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('${_transactions.length} Transactions', style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),

            if (_transactions.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 36, color: Color(0xFF484F58)),
                    SizedBox(height: 8),
                    Text('No Transactions Yet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text('Completed scheduled payouts with BMONI references will appear here.', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                  ],
                ),
              )
            else
              ..._transactions.map((tx) {
                final amount = (tx['amount'] ?? 0.0) as num;
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3FB950).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFF3FB950), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx['recipient_name'] ?? 'Recipient',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tx['bmoni_reference'] ?? 'BMONI Transfer',
                              style: const TextStyle(color: Color(0xFFB368F7), fontSize: 11, fontFamily: 'monospace'),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tx['created_at'] ?? '',
                              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '-${currencyFormat.format(amount)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3FB950).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('COMPLETED', style: TextStyle(color: Color(0xFF3FB950), fontSize: 9, fontWeight: FontWeight.bold)),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFFC9D1D9), fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
