class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    this.firstName = '',
    this.lastName = '',
    this.phoneNumber = '',
    this.avatarUrl = '',
  });

  final int id;
  final String username;
  final String email;
  final String displayName;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String avatarUrl;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final username = (json['username'] ?? '').toString();
    final email = (json['email'] ?? '').toString();
    final displayName = (json['display_name'] ?? json['full_name'] ?? username).toString();
    return AppUser(
      id: (json['id'] ?? 0) as int,
      username: username,
      email: email,
      displayName: displayName.isEmpty ? username : displayName,
      firstName: (json['first_name'] ?? '').toString(),
      lastName: (json['last_name'] ?? '').toString(),
      phoneNumber: (json['phone_number'] ?? '').toString(),
      avatarUrl: (json['avatar_url'] ?? '').toString(),
    );
  }
}

class AppGroup {
  const AppGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.members,
    this.status = 'active',
    this.myNetBalance = 0,
    this.lastActivityMessage = '',
  });

  final int id;
  final String name;
  final String description;
  final String status;
  final List<AppUser> members;
  final double myNetBalance;
  final String lastActivityMessage;

  AppGroup copyWith({
    String? name,
    String? description,
    String? status,
    List<AppUser>? members,
    double? myNetBalance,
    String? lastActivityMessage,
  }) {
    return AppGroup(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      members: members ?? this.members,
      myNetBalance: myNetBalance ?? this.myNetBalance,
      lastActivityMessage: lastActivityMessage ?? this.lastActivityMessage,
    );
  }

  factory AppGroup.fromJson(Map<String, dynamic> json) {
    final membersJson = (json['members'] as List<dynamic>? ?? <dynamic>[]);
    return AppGroup(
      id: (json['id'] ?? 0) as int,
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? 'active').toString(),
      members: membersJson
          .map((member) => AppUser.fromJson(_normalizeUser(member)))
          .toList(growable: false),
      myNetBalance: _asDouble(json['my_net_balance']),
      lastActivityMessage: (json['last_activity']?['message'] ?? '').toString(),
    );
  }
}

class AppExpenseParticipant {
  const AppExpenseParticipant({
    required this.id,
    required this.username,
    required this.shareAmount,
  });

  final int id;
  final String username;
  final double shareAmount;

  factory AppExpenseParticipant.fromJson(Map<String, dynamic> json) {
    return AppExpenseParticipant(
      id: (json['id'] ?? json['user_id'] ?? 0) as int,
      username: (json['username'] ?? '').toString(),
      shareAmount: _asDouble(json['share_amount']),
    );
  }
}

class AppExpense {
  const AppExpense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.payer,
    required this.participants,
    required this.createdAt,
  });

  final int id;
  final int groupId;
  final String description;
  final double amount;
  final AppUser payer;
  final List<AppExpenseParticipant> participants;
  final DateTime? createdAt;

  factory AppExpense.fromJson(Map<String, dynamic> json) {
    final participantsJson = (json['participants'] as List<dynamic>? ?? <dynamic>[]);
    return AppExpense(
      id: (json['id'] ?? 0) as int,
      groupId: (json['group_id'] ?? 0) as int,
      description: (json['description'] ?? '').toString(),
      amount: _asDouble(json['amount']),
      payer: AppUser.fromJson(_normalizeUser(json['payer'])),
      participants: participantsJson
          .map((participant) => AppExpenseParticipant.fromJson((participant as Map).cast<String, dynamic>()))
          .toList(growable: false),
      createdAt: _parseDate(json['created_at']),
    );
  }
}

class BalanceEntry {
  const BalanceEntry({
    required this.user,
    required this.net,
    required this.paid,
    required this.owed,
  });

  final AppUser user;
  final double net;
  final double paid;
  final double owed;

  factory BalanceEntry.fromJson(Map<String, dynamic> json) {
    return BalanceEntry(
      user: AppUser.fromJson(_normalizeUser(json['user'])),
      net: _asDouble(json['net']),
      paid: _asDouble(json['paid']),
      owed: _asDouble(json['owed']),
    );
  }
}

class SettlementSuggestion {
  const SettlementSuggestion({
    required this.fromUser,
    required this.toUser,
    required this.amount,
  });

  final AppUser fromUser;
  final AppUser toUser;
  final double amount;

  factory SettlementSuggestion.fromJson(Map<String, dynamic> json) {
    return SettlementSuggestion(
      fromUser: AppUser.fromJson(_normalizeUser(json['from_user'])),
      toUser: AppUser.fromJson(_normalizeUser(json['to_user'])),
      amount: _asDouble(json['amount']),
    );
  }
}

class BalancePayload {
  const BalancePayload({
    required this.entries,
    required this.settlements,
  });

  final List<BalanceEntry> entries;
  final List<SettlementSuggestion> settlements;

  factory BalancePayload.fromJson(Map<String, dynamic> json) {
    final balancesJson = (json['balances'] as List<dynamic>? ?? <dynamic>[]);
    final settlementsJson = (json['settlements'] as List<dynamic>? ?? <dynamic>[]);
    return BalancePayload(
      entries: balancesJson
          .map((entry) => BalanceEntry.fromJson((entry as Map).cast<String, dynamic>()))
          .toList(growable: false),
      settlements: settlementsJson
          .map((entry) => SettlementSuggestion.fromJson((entry as Map).cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}

class FeedEventItem {
  const FeedEventItem({
    required this.message,
    required this.createdAt,
    this.groupName = '',
  });

  final String message;
  final DateTime? createdAt;
  final String groupName;

  factory FeedEventItem.fromJson(Map<String, dynamic> json, {String groupName = ''}) {
    return FeedEventItem(
      message: (json['message'] ?? '').toString(),
      createdAt: _parseDate(json['created_at']),
      groupName: groupName,
    );
  }
}

Map<String, dynamic> _normalizeUser(dynamic value) {
  if (value is Map<String, dynamic>) {
    if (value['user'] is Map<String, dynamic>) {
      return (value['user'] as Map<String, dynamic>);
    }
    return value;
  }
  if (value is Map) {
    final casted = value.cast<String, dynamic>();
    if (casted['user'] is Map) {
      return (casted['user'] as Map).cast<String, dynamic>();
    }
    return casted;
  }
  return <String, dynamic>{};
}

double _asDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse('${value ?? 0}') ?? 0;
}

DateTime? _parseDate(dynamic value) {
  final raw = (value ?? '').toString().trim();
  if (raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}
