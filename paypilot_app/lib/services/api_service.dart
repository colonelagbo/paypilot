import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Use 10.0.2.2 for Android emulator, localhost for Web / Linux desktop
  static String get baseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000/api';
    }
    return 'http://localhost:4000/api';
  }

  static Future<Map<String, dynamic>> getHealth() async {
    final res = await http.get(Uri.parse('$baseUrl/health'));
    return jsonDecode(res.body);
  }

  // User Account Creation
  static Future<Map<String, dynamic>> createAccount({
    required String name,
    required String businessName,
    required String email,
    String? password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/users/create-account'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'businessName': businessName,
        'email': email,
        'password': password ?? 'secure_pass',
      }),
    );
    return jsonDecode(res.body);
  }

  // Backwards compatibility alias
  static Future<Map<String, dynamic>> onboardUser({
    required String name,
    required String businessName,
    required String email,
    String? ownerAddress,
    String? ownerPrivateKey,
  }) async {
    return createAccount(name: name, businessName: businessName, email: email);
  }

  // Get Current User and Bank Account info
  static Future<Map<String, dynamic>> getCurrentUser() async {
    final res = await http.get(Uri.parse('$baseUrl/user'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return {};
  }

  // Connect Bank Account (Any Bank)
  static Future<Map<String, dynamic>> connectBankAccount({
    required String bankName,
    required String accountNumber,
    required String accountName,
    String? bankCode,
    String? accountType,
    double? initialBalance,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/bank-accounts/connect'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'bankName': bankName,
        'accountNumber': accountNumber,
        'accountName': accountName,
        'bankCode': bankCode ?? '000',
        'accountType': accountType ?? 'Current',
        'initialBalance': initialBalance ?? 250000.0,
      }),
    );
    return jsonDecode(res.body);
  }

  // List all connected bank accounts
  static Future<List<dynamic>> getBankAccounts() async {
    final res = await http.get(Uri.parse('$baseUrl/bank-accounts'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  // Set primary bank account
  static Future<Map<String, dynamic>> setPrimaryBankAccount(String bankAccountId) async {
    final res = await http.put(Uri.parse('$baseUrl/bank-accounts/$bankAccountId/primary'));
    return jsonDecode(res.body);
  }

  // Disconnect bank account
  static Future<Map<String, dynamic>> disconnectBankAccount(String bankAccountId) async {
    final res = await http.delete(Uri.parse('$baseUrl/bank-accounts/$bankAccountId'));
    return jsonDecode(res.body);
  }

  // Top up / Add funds to bank account
  static Future<Map<String, dynamic>> fundBankAccount(String bankAccountId, double amount) async {
    final res = await http.post(
      Uri.parse('$baseUrl/bank-accounts/$bankAccountId/fund'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'amount': amount}),
    );
    return jsonDecode(res.body);
  }

  // Backward compatibility getWallet
  static Future<Map<String, dynamic>> getWallet() async {
    final res = await http.get(Uri.parse('$baseUrl/wallet'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load wallet: ${res.body}');
  }

  // Backward compatibility fundSandboxWallet
  static Future<Map<String, dynamic>> fundSandboxWallet(double amount) async {
    final res = await http.post(
      Uri.parse('$baseUrl/wallet/fund-sandbox'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'amount': amount}),
    );
    return jsonDecode(res.body);
  }

  // List supported banks
  static Future<List<dynamic>> getBanks() async {
    final res = await http.get(Uri.parse('$baseUrl/banks'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  // Resolve account name
  static Future<Map<String, dynamic>> resolveAccount({
    required String bankCode,
    required String accountNumber,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/banks/resolve'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'bankCode': bankCode,
        'accountNumber': accountNumber,
      }),
    );
    return jsonDecode(res.body);
  }

  // Recipients
  static Future<List<dynamic>> getRecipients() async {
    final res = await http.get(Uri.parse('$baseUrl/recipients'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  static Future<Map<String, dynamic>> addRecipient({
    required String name,
    required String accountNumber,
    required String bankName,
    required String bankCode,
    String? category,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/recipients'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'accountNumber': accountNumber,
        'bankName': bankName,
        'bankCode': bankCode,
        'category': category ?? 'STAFF',
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> deleteRecipient(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/recipients/$id'));
    return jsonDecode(res.body);
  }

  // Payments Scheduling
  static Future<Map<String, dynamic>> schedulePayment({
    required String recipientId,
    required double amount,
    required String paymentDate,
    String? paymentTime,
    String? description,
    String? bankAccountId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/payments/schedule'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'recipientId': recipientId,
        'amount': amount,
        'paymentDate': paymentDate,
        'paymentTime': paymentTime ?? '09:00',
        'description': description,
        'bankAccountId': bankAccountId,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> schedulePayroll({
    required List<Map<String, dynamic>> items,
    required String paymentDate,
    String? paymentTime,
    String? description,
    String? bankAccountId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/payments/schedule-payroll'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'items': items,
        'paymentDate': paymentDate,
        'paymentTime': paymentTime ?? '09:00',
        'description': description,
        'bankAccountId': bankAccountId,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getPayments() async {
    final res = await http.get(Uri.parse('$baseUrl/payments'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  static Future<Map<String, dynamic>> deletePayment(String paymentId) async {
    final res = await http.delete(Uri.parse('$baseUrl/payments/$paymentId'));
    return jsonDecode(res.body);
  }

  // Smart Pay
  static Future<Map<String, dynamic>> getSmartCheck() async {
    final res = await http.get(Uri.parse('$baseUrl/payments/smart-check'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to get smart check: ${res.body}');
  }

  static Future<Map<String, dynamic>> runSchedulerNow() async {
    final res = await http.post(Uri.parse('$baseUrl/payments/run-now'));
    return jsonDecode(res.body);
  }

  // Transactions
  static Future<List<dynamic>> getTransactions() async {
    final res = await http.get(Uri.parse('$baseUrl/transactions'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }
}
