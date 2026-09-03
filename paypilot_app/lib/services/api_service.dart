import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Use current browser origin for Web, 10.0.2.2 for Android emulator, localhost for native desktop
  static String get baseUrl {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && origin != 'null' && !origin.startsWith('file:')) {
        return '$origin/api';
      }
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000/api';
    }
    return 'http://localhost:4000/api';
  }

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

  static Future<Map<String, dynamic>> createOnboardingChallenge({
    required String name,
    required String businessName,
    required String email,
    required String ownerAddress,
    String? phoneNumber,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/users/onboard/challenge'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'businessName': businessName,
        'email': email,
        'ownerAddress': ownerAddress,
        'phoneNumber': phoneNumber,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? 'Unable to create onboarding challenge');
    return Map<String, dynamic>.from(body);
  }

  static Future<Map<String, dynamic>> completeOnboarding({
    required String name,
    required String businessName,
    required String email,
    required String ownerAddress,
    required String bmoniUserId,
    required String ownerProofChallengeId,
    required String ownerProofSignature,
    required String bvn,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/users/onboard/complete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name, 'businessName': businessName, 'email': email,
        'ownerAddress': ownerAddress, 'bmoniUserId': bmoniUserId,
        'ownerProofChallengeId': ownerProofChallengeId,
        'ownerProofSignature': ownerProofSignature, 'bvn': bvn,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? 'Onboarding failed');
    return Map<String, dynamic>.from(body);
  }

  static Future<Map<String, dynamic>> getWallet() async {
    final res = await http.get(Uri.parse('$baseUrl/wallet'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load wallet: ${res.body}');
  }


  static Future<Map<String, dynamic>> getDepositAccount() async {
    final res = await http.get(Uri.parse('$baseUrl/wallet/deposit-account'));
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? 'Failed to load deposit account');
    return Map<String, dynamic>.from(body);
  }

  static Future<Map<String, dynamic>> startNgnOnramp() async {
    final res = await http.post(Uri.parse('$baseUrl/wallet/onramp'));
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? 'Failed to start NGN funding');
    return Map<String, dynamic>.from(body);
  }

  static Future<Map<String, dynamic>> getOnboardingStatus() async {
    final res = await http.get(Uri.parse('$baseUrl/wallet/onboarding-status'));
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? 'Failed to load onboarding status');
    return Map<String, dynamic>.from(body);
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

  static Future<Map<String, dynamic>> verifyRecipient({required String bankCode, required String accountNumber}) async {
    final res = await http.post(Uri.parse('$baseUrl/recipients/verify'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'bankCode': bankCode, 'accountNumber': accountNumber}));
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? 'Account verification failed');
    return Map<String, dynamic>.from(body);
  }

  static Future<Map<String, dynamic>> addRecipient({required String name, required String accountNumber, required String bankName, required String bankCode, String? category}) async {
    final res = await http.post(Uri.parse('$baseUrl/recipients'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'name': name, 'accountNumber': accountNumber, 'bankName': bankName, 'bankCode': bankCode, 'category': category ?? 'STAFF'}));
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? 'Failed to add recipient');
    return Map<String, dynamic>.from(body);
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
    final res = await http.delete(Uri.parse('$baseUrl/payments/$paymentId'));
    return jsonDecode(res.body);
  }

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

  static Future<Map<String, dynamic>> preparePaymentSignature(String paymentId) async {
    final res = await http.post(Uri.parse('$baseUrl/payments/$paymentId/prepare-signature'));
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? 'Payment is not ready for signing');
    return Map<String, dynamic>.from(body);
  }

  static Future<Map<String, dynamic>> submitPaymentSignature(String paymentId, String signature) async {
    final res = await http.post(Uri.parse('$baseUrl/payments/$paymentId/signature'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'signature': signature}));
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? 'Payment signature failed');
    return Map<String, dynamic>.from(body);
  }

  static Future<List<dynamic>> getTransactions() async {
    final res = await http.get(Uri.parse('$baseUrl/transactions'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  static Future<Map<String, dynamic>> fetchWallets() async {
    final res = await http.get(Uri.parse('$baseUrl/wallets'));
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? 'Failed to fetch wallets');
    return Map<String, dynamic>.from(body);
  }

  static Future<Map<String, dynamic>> fetchWalletDetail(String walletId) async {
    final res = await http.get(Uri.parse('$baseUrl/wallets/$walletId'));
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? 'Failed to fetch wallet detail');
    return Map<String, dynamic>.from(body);
  }

  static Future<Map<String, dynamic>> fetchBalance(String walletId) async {
    final res = await http.get(Uri.parse('$baseUrl/wallets/$walletId/balance'));
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? 'Failed to fetch balance');
    return Map<String, dynamic>.from(body);
  }

  static Future<Map<String, dynamic>> fetchTransactions(
    String walletId, {
    int? page,
    int? pageSize,
  }) async {
    final uri = Uri.parse('$baseUrl/wallets/$walletId/transactions').replace(
      queryParameters: {
        if (page != null) 'page': page.toString(),
        if (pageSize != null) 'pageSize': pageSize.toString(),
      },
    );
    final res = await http.get(uri);
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? 'Failed to fetch transactions');
    return Map<String, dynamic>.from(body);
  }
}
