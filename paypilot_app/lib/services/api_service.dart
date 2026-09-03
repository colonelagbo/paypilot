import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Production backend hosted on Railway
  static const String baseUrl =
      'https://paypilot-production-c517.up.railway.app/api';

  static Future<Map<String, dynamic>> getHealth() async {
    final res = await http.get(Uri.parse('$baseUrl/health'));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getCurrentUser() async {
    final res = await http.get(Uri.parse('$baseUrl/user'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return {};
  }

  static Future<Map<String, dynamic>> onboardUser({
    required String name,
    required String businessName,
    required String email,
    required String ownerAddress,
    String? ownerPrivateKey,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/users/onboard'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'businessName': businessName,
        'email': email,
        'userOwnerAddress': ownerAddress,
        'ownerPrivateKey': ownerPrivateKey,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getWallet() async {
    final res = await http.get(Uri.parse('$baseUrl/wallet'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load wallet: ${res.body}');
  }

  static Future<Map<String, dynamic>> fundSandboxWallet(double amount) async {
    final res = await http.post(
      Uri.parse('$baseUrl/wallet/fund-sandbox'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'amount': amount}),
    );
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getBanks() async {
    final res = await http.get(Uri.parse('$baseUrl/banks'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

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
    String? walletAddress,
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
        'walletAddress': walletAddress,
        'category': category ?? 'STAFF',
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> schedulePayment({
    required String recipientId,
    required double amount,
    required String paymentDate,
    String? paymentTime,
    String? description,
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
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> schedulePayroll({
    required List<Map<String, dynamic>> items,
    required String paymentDate,
    String? paymentTime,
    String? description,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/payments/schedule-payroll'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'items': items,
        'paymentDate': paymentDate,
        'paymentTime': paymentTime ?? '09:00',
        'description': description,
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
    final res = await http.delete(
      Uri.parse('$baseUrl/payments/$paymentId'),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getSmartCheck() async {
    final res = await http.get(
      Uri.parse('$baseUrl/payments/smart-check'),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to get smart check: ${res.body}');
  }

  static Future<Map<String, dynamic>> runSchedulerNow() async {
    final res = await http.post(
      Uri.parse('$baseUrl/payments/run-now'),
    );
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getTransactions() async {
    final res = await http.get(Uri.parse('$baseUrl/transactions'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }
}