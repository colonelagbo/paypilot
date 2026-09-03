// SPDX-License-Identifier: Apache-2.0

/// Direction of an embedded wallet transaction.
enum EmbeddedTransactionDirection {
  incoming,
  outgoing;

  static EmbeddedTransactionDirection fromString(String? value) {
    if (value == null) return incoming;
    final normalized = value.toLowerCase().trim();
    if (normalized == 'outgoing' || normalized == 'debit' || normalized == 'out') {
      return EmbeddedTransactionDirection.outgoing;
    }
    return EmbeddedTransactionDirection.incoming;
  }
}

/// Lifecycle status of an embedded wallet transaction.
enum EmbeddedWalletTransactionStatus {
  pending,
  completed,
  failed,
  reversed;

  static EmbeddedWalletTransactionStatus fromString(String? value) {
    if (value == null) return pending;
    final normalized = value.toLowerCase().trim();
    switch (normalized) {
      case 'completed':
      case 'successful':
      case 'success':
      case 'executed':
        return EmbeddedWalletTransactionStatus.completed;
      case 'failed':
      case 'rejected':
        return EmbeddedWalletTransactionStatus.failed;
      case 'reversed':
      case 'refunded':
        return EmbeddedWalletTransactionStatus.reversed;
      default:
        return EmbeddedWalletTransactionStatus.pending;
    }
  }
}

/// Core embedded wallet read model.
class EmbeddedWallet {
  const EmbeddedWallet({
    required this.walletId,
    required this.name,
    required this.currency,
    required this.balance,
    this.colorSuffix,
    this.walletAddress,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String walletId;
  final String name;
  final String currency;
  final double balance;
  final String? colorSuffix;
  final String? walletAddress;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EmbeddedWallet copyWith({
    String? walletId,
    String? name,
    String? currency,
    double? balance,
    String? colorSuffix,
    String? walletAddress,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmbeddedWallet(
      walletId: walletId ?? this.walletId,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      balance: balance ?? this.balance,
      colorSuffix: colorSuffix ?? this.colorSuffix,
      walletAddress: walletAddress ?? this.walletAddress,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory EmbeddedWallet.fromJson(Map<String, dynamic> json) {
    final rawBalance = json['balance'] ?? json['currentBalance'] ?? 0;
    final balanceVal = rawBalance is num
        ? rawBalance.toDouble()
        : double.tryParse(rawBalance.toString()) ?? 0.0;

    return EmbeddedWallet(
      walletId: (json['walletId'] ?? json['id'] ?? json['smartWalletId'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? '${json['currency'] ?? 'BMONI'} Wallet').toString(),
      currency: (json['currency'] ?? 'CNGN').toString(),
      balance: balanceVal,
      colorSuffix: json['colorSuffix']?.toString(),
      walletAddress: json['walletAddress']?.toString() ?? json['address']?.toString(),
      isActive: json['isActive'] is bool ? json['isActive'] as bool : true,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'walletId': walletId,
    'name': name,
    'currency': currency,
    'balance': balance,
    if (colorSuffix != null) 'colorSuffix': colorSuffix,
    if (walletAddress != null) 'walletAddress': walletAddress,
    'isActive': isActive,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmbeddedWallet &&
          runtimeType == other.runtimeType &&
          walletId == other.walletId &&
          currency == other.currency &&
          balance == other.balance;

  @override
  int get hashCode => Object.hash(runtimeType, walletId, currency, balance);

  @override
  String toString() => 'EmbeddedWallet(walletId: $walletId, currency: $currency, balance: $balance)';
}

/// Response payload containing a list of embedded wallets.
class EmbeddedWalletListResponse {
  const EmbeddedWalletListResponse({required this.wallets});

  final List<EmbeddedWallet> wallets;

  factory EmbeddedWalletListResponse.fromJson(dynamic json) {
    if (json is List) {
      return EmbeddedWalletListResponse(
        wallets: json
            .map((item) => EmbeddedWallet.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
      );
    }
    if (json is Map) {
      final list = json['wallets'] ?? json['data'] ?? [];
      if (list is List) {
        return EmbeddedWalletListResponse(
          wallets: list
              .map((item) => EmbeddedWallet.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList(),
        );
      }
    }
    return const EmbeddedWalletListResponse(wallets: []);
  }

  Map<String, dynamic> toJson() => {
    'wallets': wallets.map((w) => w.toJson()).toList(),
  };
}

/// Response payload containing a single embedded wallet detail.
class EmbeddedWalletDetailResponse {
  const EmbeddedWalletDetailResponse({required this.wallet});

  final EmbeddedWallet wallet;

  factory EmbeddedWalletDetailResponse.fromJson(dynamic json) {
    if (json is Map) {
      final inner = json['wallet'] ?? json['data'] ?? json;
      return EmbeddedWalletDetailResponse(
        wallet: EmbeddedWallet.fromJson(Map<String, dynamic>.from(inner as Map)),
      );
    }
    throw const FormatException('Expected JSON object for EmbeddedWalletDetailResponse');
  }

  Map<String, dynamic> toJson() => {
    'wallet': wallet.toJson(),
  };
}

/// Response payload containing balance information for an embedded wallet.
class EmbeddedWalletBalanceResponse {
  const EmbeddedWalletBalanceResponse({
    required this.walletId,
    required this.balance,
    this.currency,
  });

  final String walletId;
  final double balance;
  final String? currency;

  factory EmbeddedWalletBalanceResponse.fromJson(dynamic json) {
    if (json is Map) {
      final inner = json['data'] is Map ? json['data'] as Map : json;
      final rawBalance = inner['balance'] ?? 0;
      final balanceVal = rawBalance is num
          ? rawBalance.toDouble()
          : double.tryParse(rawBalance.toString()) ?? 0.0;
      return EmbeddedWalletBalanceResponse(
        walletId: (inner['smartWalletId'] ?? inner['walletId'] ?? inner['id'] ?? '').toString(),
        balance: balanceVal,
        currency: inner['currency']?.toString(),
      );
    }
    throw const FormatException('Expected JSON object for EmbeddedWalletBalanceResponse');
  }

  Map<String, dynamic> toJson() => {
    'walletId': walletId,
    'balance': balance,
    if (currency != null) 'currency': currency,
  };
}

/// Single transaction record for an embedded wallet.
class EmbeddedWalletTransaction {
  const EmbeddedWalletTransaction({
    required this.id,
    required this.walletId,
    required this.amount,
    this.currency,
    this.direction = EmbeddedTransactionDirection.incoming,
    this.status = EmbeddedWalletTransactionStatus.completed,
    this.title,
    this.counterpartyName,
    this.createdAt,
    this.reference,
  });

  final String id;
  final String walletId;
  final double amount;
  final String? currency;
  final EmbeddedTransactionDirection direction;
  final EmbeddedWalletTransactionStatus status;
  final String? title;
  final String? counterpartyName;
  final DateTime? createdAt;
  final String? reference;

  /// Convenience boolean to check if the transaction is incoming.
  bool get isIncoming => direction == EmbeddedTransactionDirection.incoming;

  factory EmbeddedWalletTransaction.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'] ?? 0;
    final amountVal = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount.toString()) ?? 0.0;

    return EmbeddedWalletTransaction(
      id: (json['id'] ?? json['transactionId'] ?? json['bmoni_reference'] ?? '').toString(),
      walletId: (json['walletId'] ?? json['smartWalletId'] ?? '').toString(),
      amount: amountVal,
      currency: json['currency']?.toString(),
      direction: EmbeddedTransactionDirection.fromString(json['direction']?.toString()),
      status: EmbeddedWalletTransactionStatus.fromString(json['status']?.toString()),
      title: json['title']?.toString() ?? json['description']?.toString(),
      counterpartyName: json['counterpartyName']?.toString() ?? json['recipient_name']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null),
      reference: json['reference']?.toString() ?? json['bmoni_reference']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'walletId': walletId,
    'amount': amount,
    if (currency != null) 'currency': currency,
    'direction': direction.name,
    'status': status.name,
    if (title != null) 'title': title,
    if (counterpartyName != null) 'counterpartyName': counterpartyName,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (reference != null) 'reference': reference,
  };
}

/// Response payload containing transaction history.
class EmbeddedWalletTransactionsResponse {
  const EmbeddedWalletTransactionsResponse({
    required this.transactions,
    this.total,
    this.page,
    this.pageSize,
  });

  final List<EmbeddedWalletTransaction> transactions;
  final int? total;
  final int? page;
  final int? pageSize;

  factory EmbeddedWalletTransactionsResponse.fromJson(dynamic json) {
    if (json is List) {
      return EmbeddedWalletTransactionsResponse(
        transactions: json
            .map((item) => EmbeddedWalletTransaction.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
      );
    }
    if (json is Map) {
      final data = json['data'] is Map ? json['data'] as Map : json;
      final txList = data['transactions'] ?? json['transactions'] ?? [];
      if (txList is List) {
        return EmbeddedWalletTransactionsResponse(
          transactions: txList
              .map((item) => EmbeddedWalletTransaction.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList(),
          total: json['total'] as int?,
          page: json['page'] as int?,
          pageSize: json['pageSize'] as int?,
        );
      }
    }
    return const EmbeddedWalletTransactionsResponse(transactions: []);
  }

  Map<String, dynamic> toJson() => {
    'transactions': transactions.map((t) => t.toJson()).toList(),
    if (total != null) 'total': total,
    if (page != null) 'page': page,
    if (pageSize != null) 'pageSize': pageSize,
  };
}
