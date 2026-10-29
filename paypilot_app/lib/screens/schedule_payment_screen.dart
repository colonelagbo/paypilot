import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class SchedulePaymentScreen extends StatefulWidget {
  final VoidCallback onPaymentScheduled;

  const SchedulePaymentScreen({super.key, required this.onPaymentScheduled});

  @override
  State<SchedulePaymentScreen> createState() => _SchedulePaymentScreenState();
}

class _SchedulePaymentScreenState extends State<SchedulePaymentScreen> {
  final _amountController = TextEditingController(text: '15000');
  final _descriptionController = TextEditingController(text: 'Monthly Vendor Invoice');
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);

  List<dynamic> _recipients = [];
  List<dynamic> _banks = [];
  String? _selectedRecipientId;
  bool _isLoading = true;
  bool _isSubmitting = false;

  final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final recs = await ApiService.getRecipients();
      final banks = await ApiService.getBanks();
      if (mounted) {
        setState(() {
          _recipients = recs;
          _banks = banks;
          if (_recipients.isNotEmpty) {
            _selectedRecipientId = _recipients.first['id'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddRecipientModal() async {
    final nameCtrl = TextEditingController();
    final acctCtrl = TextEditingController();
    String selectedBankName = _banks.isNotEmpty ? _banks.first['bankName'] : 'Access Bank';
    String selectedBankCode = _banks.isNotEmpty ? _banks.first['bankCode'] : '044';
    String selectedCategory = 'STAFF';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add New Recipient', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: Color(0xFF8B949E)), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Recipient Name', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. Adebayo Ogunlesi',
                  hintStyle: const TextStyle(color: Color(0xFF484F58)),
                  filled: true,
                  fillColor: const Color(0xFF0D1117),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Recipient Type', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildCategoryChip(
                      label: 'Staff',
                      icon: Icons.badge_outlined,
                      isSelected: selectedCategory == 'STAFF',
                      color: const Color(0xFFB368F7),
                      onTap: () => setModalState(() => selectedCategory = 'STAFF'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCategoryChip(
                      label: 'Supplier',
                      icon: Icons.local_shipping_outlined,
                      isSelected: selectedCategory == 'SUPPLIER',
                      color: const Color(0xFF58A6FF),
                      onTap: () => setModalState(() => selectedCategory = 'SUPPLIER'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCategoryChip(
                      label: 'Other',
                      icon: Icons.category_outlined,
                      isSelected: selectedCategory == 'OTHER',
                      color: const Color(0xFFE3B341),
                      onTap: () => setModalState(() => selectedCategory = 'OTHER'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Bank', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: DropdownButton<String>(
                  value: selectedBankName,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF161B22),
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.white),
                  items: _banks.take(30).map((b) {
                    final name = b['bankName'].toString();
                    return DropdownMenuItem<String>(value: name, child: Text(name, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final match = _banks.firstWhere((b) => b['bankName'] == val, orElse: () => null);
                      setModalState(() {
                        selectedBankName = val;
                        if (match != null) selectedBankCode = match['bankCode'];
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 14),
              const Text('Account Number (10 Digits)', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: acctCtrl,
                keyboardType: TextInputType.number,
                maxLength: 10,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '0123456789',
                  hintStyle: const TextStyle(color: Color(0xFF484F58)),
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFF0D1117),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7526C9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty || acctCtrl.text.trim().length != 10) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid name and 10-digit account number')),
                    );
                    return;
                  }
                  final newRec = await ApiService.addRecipient(
                    name: nameCtrl.text.trim(),
                    accountNumber: acctCtrl.text.trim(),
                    bankName: selectedBankName,
                    bankCode: selectedBankCode,
                    category: selectedCategory,
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  await _loadData();
                  if (!mounted) return;
                  setState(() {
                    _selectedRecipientId = newRec['id'];
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Recipient '${newRec['name']}' [$selectedCategory] added! Now set amount & date, then tap 'Schedule Bank Transfer'."),
                      backgroundColor: const Color(0xFF7526C9),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                },
                child: const Text('Save Recipient', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF30363D),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: isSelected ? color : const Color(0xFF8B949E)),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : const Color(0xFF8B949E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitSchedule() async {
    if (_selectedRecipientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a recipient')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid positive amount')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final timeStr = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

      await ApiService.schedulePayment(
        recipientId: _selectedRecipientId!,
        amount: amount,
        paymentDate: dateStr,
        paymentTime: timeStr,
        description: _descriptionController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment scheduled successfully!'),
            backgroundColor: Color(0xFF3FB950),
          ),
        );
        widget.onPaymentScheduled();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scheduling failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Schedule Payment', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF7526C9).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF7526C9).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFFB368F7), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'PayPilot watches your scheduled payment, verifies connected bank balance before due date, and automates transfer execution.',
                      style: TextStyle(color: Color(0xFFD8B4FE), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Form Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recipient Picker
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recipient', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: _showAddRecipientModal,
                        icon: const Icon(Icons.add, size: 16, color: Color(0xFFB368F7)),
                        label: const Text('Add New', style: TextStyle(color: Color(0xFFB368F7), fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_recipients.isEmpty)
                    InkWell(
                      onTap: _showAddRecipientModal,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1117),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF7526C9).withOpacity(0.4)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_add_alt_1_rounded, size: 18, color: Color(0xFFB368F7)),
                            SizedBox(width: 8),
                            Text('Tap to add your first recipient', style: TextStyle(color: Color(0xFFB368F7), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1117),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF30363D)),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedRecipientId,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF161B22),
                        underline: const SizedBox(),
                        style: const TextStyle(color: Colors.white),
                        items: _recipients.map((r) {
                          final cat = (r['category'] ?? 'STAFF').toString().toUpperCase();
                          Color tagColor = const Color(0xFFB368F7);
                          if (cat == 'SUPPLIER') tagColor = const Color(0xFF58A6FF);
                          if (cat == 'OTHER') tagColor = const Color(0xFFE3B341);

                          return DropdownMenuItem<String>(
                            value: r['id'].toString(),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: tagColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: tagColor.withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    cat,
                                    style: TextStyle(color: tagColor, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${r['name']} • ${r['bank_name']} (${r['account_number']})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedRecipientId = val),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Amount
                  const Text('Amount (₦)', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      prefixText: '₦ ',
                      prefixStyle: const TextStyle(color: Colors.white, fontSize: 18),
                      filled: true,
                      fillColor: const Color(0xFF0D1117),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Date & Time Picker
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Payment Date', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) setState(() => _selectedDate = picked);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D1117),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF30363D)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(DateFormat('MMM dd, yyyy').format(_selectedDate), style: const TextStyle(color: Colors.white)),
                                    const Icon(Icons.calendar_month, size: 16, color: Color(0xFFB368F7)),
                                  ],
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
                            const Text('Execution Time', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: _selectedTime,
                                );
                                if (picked != null) setState(() => _selectedTime = picked);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D1117),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF30363D)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_selectedTime.format(context), style: const TextStyle(color: Colors.white)),
                                    const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFFB368F7)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Description
                  const Text('Description (Optional)', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _descriptionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g. Office rent or supplier fee',
                      hintStyle: const TextStyle(color: Color(0xFF484F58)),
                      filled: true,
                      fillColor: const Color(0xFF0D1117),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitSchedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7526C9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.schedule_send_rounded, size: 20),
                        SizedBox(width: 8),
                        Text('Schedule Bank Transfer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
