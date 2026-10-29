import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class SchedulePayrollScreen extends StatefulWidget {
  final VoidCallback onPayrollScheduled;

  const SchedulePayrollScreen({super.key, required this.onPayrollScheduled});

  @override
  State<SchedulePayrollScreen> createState() => _SchedulePayrollScreenState();
}

class _SchedulePayrollScreenState extends State<SchedulePayrollScreen> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);

  List<dynamic> _recipients = [];
  final Map<String, bool> _selectedRecipients = {};
  final Map<String, TextEditingController> _amountControllers = {};

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
      var recs = await ApiService.getRecipients();

      // If no recipients, seed 3 sample staff members for instant demo convenience
      if (recs.isEmpty) {
        final r1 = await ApiService.addRecipient(name: 'Chidi Okafor (Engineering)', accountNumber: '0123456781', bankName: 'Access Bank', bankCode: '044');
        final r2 = await ApiService.addRecipient(name: 'Fatima Bello (Design)', accountNumber: '0123456782', bankName: 'GTBank', bankCode: '058');
        final r3 = await ApiService.addRecipient(name: 'Emeka Eze (Marketing)', accountNumber: '0123456783', bankName: 'First Bank', bankCode: '011');
        recs = [r1, r2, r3];
      }

      if (mounted) {
        setState(() {
          _recipients = recs;
          for (var r in _recipients) {
            final id = r['id'].toString();
            _selectedRecipients[id] = true;
            _amountControllers[id] = TextEditingController(text: '75000');
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _calculateRunningTotal() {
    double total = 0.0;
    for (var r in _recipients) {
      final id = r['id'].toString();
      if (_selectedRecipients[id] == true) {
        final amt = double.tryParse(_amountControllers[id]?.text ?? '0') ?? 0.0;
        total += amt;
      }
    }
    return total;
  }

  int _selectedCount() {
    return _selectedRecipients.values.where((v) => v == true).length;
  }

  Future<void> _submitPayroll() async {
    final items = <Map<String, dynamic>>[];
    for (var r in _recipients) {
      final id = r['id'].toString();
      if (_selectedRecipients[id] == true) {
        final amt = double.tryParse(_amountControllers[id]?.text ?? '0') ?? 0.0;
        if (amt > 0) {
          items.add({'recipientId': id, 'amount': amt});
        }
      }
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one recipient with a valid salary amount')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final timeStr = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

      await ApiService.schedulePayroll(
        items: items,
        paymentDate: dateStr,
        paymentTime: timeStr,
        description: 'Monthly Payroll Batch (${items.length} Employees)',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scheduled payroll batch for ${items.length} employees (${currencyFormat.format(_calculateRunningTotal())})!'),
            backgroundColor: const Color(0xFF3FB950),
          ),
        );
        widget.onPayrollScheduled();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payroll scheduling failed: $e'), backgroundColor: Colors.red),
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

    final runningTotal = _calculateRunningTotal();
    final count = _selectedCount();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Schedule Payroll', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          border: const Border(top: BorderSide(color: Color(0xFF30363D))),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Running Total ($count staff)', style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        currencyFormat.format(runningTotal),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: _isSubmitting || count == 0 ? null : _submitPayroll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7526C9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Schedule Payroll Batch', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF7526C9).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF7526C9).withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.groups_rounded, color: Color(0xFFB368F7), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Select employees and assign amounts. PayPilot verifies your connected bank balance before execution and notifies you of any shortfall.',
                    style: TextStyle(color: Color(0xFFD8B4FE), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Date and Time Row
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
                const Text('Payroll Execution Date & Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1117),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF30363D)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('MMM dd, yyyy').format(_selectedDate), style: const TextStyle(color: Colors.white, fontSize: 13)),
                              const Icon(Icons.calendar_month, size: 16, color: Color(0xFFB368F7)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime,
                          );
                          if (picked != null) setState(() => _selectedTime = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1117),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF30363D)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_selectedTime.format(context), style: const TextStyle(color: Colors.white, fontSize: 13)),
                              const Icon(Icons.access_time, size: 16, color: Color(0xFFB368F7)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Employees Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recipients / Employees', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              TextButton(
                onPressed: () {
                  final allSelected = _selectedCount() == _recipients.length;
                  setState(() {
                    for (var r in _recipients) {
                      _selectedRecipients[r['id'].toString()] = !allSelected;
                    }
                  });
                },
                child: Text(
                  _selectedCount() == _recipients.length ? 'Deselect All' : 'Select All',
                  style: const TextStyle(color: Color(0xFFB368F7), fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Employee List with Checkboxes and Amount Inputs
          ..._recipients.map((rec) {
            final id = rec['id'].toString();
            final isSelected = _selectedRecipients[id] ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF161B22) : const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFF7526C9).withOpacity(0.5) : const Color(0xFF21262D),
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    activeColor: const Color(0xFF7526C9),
                    onChanged: (val) {
                      setState(() {
                        _selectedRecipients[id] = val ?? false;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              rec['name'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : const Color(0xFF8B949E),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(rec['category']).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                (rec['category'] ?? 'STAFF').toString().toUpperCase(),
                                style: TextStyle(
                                  color: _getCategoryColor(rec['category']),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${rec['bank_name']} • ${rec['account_number']}',
                          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _amountControllers[id],
                      enabled: isSelected,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        prefixText: '₦',
                        prefixStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        filled: true,
                        fillColor: const Color(0xFF0D1117),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF30363D))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF30363D))),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    switch ((category ?? 'STAFF').toUpperCase()) {
      case 'SUPPLIER':
        return const Color(0xFF58A6FF);
      case 'OTHER':
        return const Color(0xFFE3B341);
      case 'STAFF':
      default:
        return const Color(0xFFB368F7);
    }
  }
}
