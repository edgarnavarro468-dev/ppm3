class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    this.publicCode = '',
    this.firstName = '',
    this.lastName = '',
    this.phoneNumber = '',
    this.avatarUrl = '',
    this.groupRole = 'member',
    this.membershipStatus = 'active',
  });

  final int id;
  final String username;
  final String email;
  final String displayName;
  final String publicCode;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String avatarUrl;
  final String groupRole;
  final String membershipStatus;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final username = (json['username'] ?? '').toString();
    final email = (json['email'] ?? '').toString();
    final displayName =
        (json['display_name'] ?? json['full_name'] ?? username).toString();
    return AppUser(
      id: (json['id'] ?? 0) as int,
      username: username,
      email: email,
      displayName: displayName.isEmpty ? username : displayName,
      publicCode: (json['public_code'] ?? json['invite_code'] ?? '').toString(),
      firstName: (json['first_name'] ?? '').toString(),
      lastName: (json['last_name'] ?? '').toString(),
      phoneNumber: (json['phone_number'] ?? '').toString(),
      avatarUrl: (json['avatar_url'] ?? '').toString(),
      groupRole: (json['group_role'] ?? 'member').toString(),
      membershipStatus: (json['membership_status'] ?? 'active').toString(),
    );
  }
}

class AppGroup {
  const AppGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.members,
    this.createdBy = 0,
    this.status = 'active',
    this.myNetBalance = 0,
    this.lastActivityMessage = '',
  });

  final int id;
  final String name;
  final String description;
  final int createdBy;
  final String status;
  final List<AppUser> members;
  final double myNetBalance;
  final String lastActivityMessage;

  AppGroup copyWith({
    String? name,
    String? description,
    int? createdBy,
    String? status,
    List<AppUser>? members,
    double? myNetBalance,
    String? lastActivityMessage,
  }) {
    return AppGroup(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
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
      createdBy: (json['created_by'] ?? 0) as int,
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
    final participantsJson =
        (json['participants'] as List<dynamic>? ?? <dynamic>[]);
    return AppExpense(
      id: (json['id'] ?? 0) as int,
      groupId: (json['group_id'] ?? 0) as int,
      description: (json['description'] ?? '').toString(),
      amount: _asDouble(json['amount']),
      payer: AppUser.fromJson(_normalizeUser(json['payer'])),
      participants: participantsJson
          .map((participant) => AppExpenseParticipant.fromJson(
              (participant as Map).cast<String, dynamic>()))
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

class AppSettlement {
  const AppSettlement({
    required this.id,
    required this.groupId,
    required this.fromUser,
    required this.toUser,
    required this.amount,
    required this.notes,
    required this.receivedConfirmed,
    required this.fromConfirmed,
    required this.toConfirmed,
    required this.createdAt,
    this.receivedConfirmedAt,
    this.receivedConfirmedBy,
    this.createdBy,
  });

  final int id;
  final int groupId;
  final AppUser fromUser;
  final AppUser toUser;
  final double amount;
  final String notes;
  final bool receivedConfirmed;
  final bool fromConfirmed;
  final bool toConfirmed;
  final DateTime? createdAt;
  final DateTime? receivedConfirmedAt;
  final AppUser? receivedConfirmedBy;
  final AppUser? createdBy;

  factory AppSettlement.fromJson(Map<String, dynamic> json) {
    return AppSettlement(
      id: (json['id'] ?? 0) as int,
      groupId: (json['group_id'] ?? 0) as int,
      fromUser: AppUser.fromJson(_normalizeUser(json['from_user'])),
      toUser: AppUser.fromJson(_normalizeUser(json['to_user'])),
      amount: _asDouble(json['amount']),
      notes: (json['notes'] ?? '').toString(),
      receivedConfirmed: json['received_confirmed'] == true,
      fromConfirmed: json['from_confirmed'] == true,
      toConfirmed: json['to_confirmed'] == true,
      createdAt: _parseDate(json['created_at']),
      receivedConfirmedAt: _parseDate(json['received_confirmed_at']),
      receivedConfirmedBy: _maybeUser(json['received_confirmed_by']),
      createdBy: _maybeUser(json['created_by']),
    );
  }
}

class AppContact {
  const AppContact({
    required this.id,
    required this.nickname,
    required this.createdAt,
    required this.user,
  });

  final int id;
  final String nickname;
  final DateTime? createdAt;
  final AppUser user;

  factory AppContact.fromJson(Map<String, dynamic> json) {
    return AppContact(
      id: (json['id'] ?? 0) as int,
      nickname: (json['nickname'] ?? '').toString(),
      createdAt: _parseDate(json['created_at']),
      user: AppUser.fromJson(_normalizeUser(json['user'])),
    );
  }
}

class AppProposal {
  const AppProposal({
    required this.id,
    required this.groupId,
    required this.creator,
    required this.title,
    required this.details,
    required this.activityType,
    required this.availabilityText,
    required this.providerName,
    required this.providerDetails,
    required this.providerUrl,
    required this.paymentDueDate,
    required this.scheduledForDate,
    required this.voteDeadline,
    required this.totalAmount,
    required this.paymentMethod,
    required this.confirmationStatus,
    required this.isSharedDebt,
    required this.status,
    required this.createdAt,
    required this.voteCount,
    required this.voteThreshold,
    required this.voters,
    this.payerUser,
  });

  final int id;
  final int groupId;
  final AppUser creator;
  final AppUser? payerUser;
  final String title;
  final String details;
  final String activityType;
  final String availabilityText;
  final String providerName;
  final String providerDetails;
  final String providerUrl;
  final String paymentDueDate;
  final String scheduledForDate;
  final String voteDeadline;
  final double totalAmount;
  final String paymentMethod;
  final String confirmationStatus;
  final bool isSharedDebt;
  final String status;
  final DateTime? createdAt;
  final int voteCount;
  final int voteThreshold;
  final List<AppUser> voters;

  factory AppProposal.fromJson(Map<String, dynamic> json) {
    final votersJson = (json['voters'] as List<dynamic>? ?? <dynamic>[]);
    return AppProposal(
      id: (json['id'] ?? 0) as int,
      groupId: (json['group_id'] ?? 0) as int,
      creator: AppUser.fromJson(_normalizeUser(json['creator'])),
      payerUser: _maybeUser(json['payer_user']),
      title: (json['title'] ?? '').toString(),
      details: (json['details'] ?? '').toString(),
      activityType: (json['activity_type'] ?? '').toString(),
      availabilityText: (json['availability_text'] ?? '').toString(),
      providerName: (json['provider_name'] ?? '').toString(),
      providerDetails: (json['provider_details'] ?? '').toString(),
      providerUrl: (json['provider_url'] ?? '').toString(),
      paymentDueDate: (json['payment_due_date'] ?? '').toString(),
      scheduledForDate: (json['scheduled_for_date'] ?? '').toString(),
      voteDeadline: (json['vote_deadline'] ?? '').toString(),
      totalAmount: _asDouble(json['total_amount']),
      paymentMethod: (json['payment_method'] ?? '').toString(),
      confirmationStatus: (json['confirmation_status'] ?? '').toString(),
      isSharedDebt: json['is_shared_debt'] != false,
      status: (json['status'] ?? '').toString(),
      createdAt: _parseDate(json['created_at']),
      voteCount: (json['vote_count'] ?? 0) as int,
      voteThreshold: (json['vote_threshold'] ?? 0) as int,
      voters: votersJson
          .map((item) => AppUser.fromJson(_normalizeUser(item)))
          .toList(growable: false),
    );
  }
}

class AppRatingEntry {
  const AppRatingEntry({
    required this.id,
    required this.score,
    required this.title,
    required this.comment,
    required this.createdAt,
    required this.rater,
    required this.ratedUser,
  });

  final int id;
  final int score;
  final String title;
  final String comment;
  final DateTime? createdAt;
  final AppUser rater;
  final AppUser ratedUser;

  factory AppRatingEntry.fromJson(Map<String, dynamic> json) {
    return AppRatingEntry(
      id: (json['id'] ?? 0) as int,
      score: (json['score'] ?? 0) as int,
      title: (json['title'] ?? '').toString(),
      comment: (json['comment'] ?? '').toString(),
      createdAt: _parseDate(json['created_at']),
      rater: AppUser.fromJson(_normalizeUser(json['rater'])),
      ratedUser: AppUser.fromJson(_normalizeUser(json['rated_user'])),
    );
  }
}

class AppLeaderboardUser {
  const AppLeaderboardUser({
    required this.user,
    required this.averageScore,
    required this.ratingCount,
    required this.badgeTitle,
    required this.customTitles,
  });

  final AppUser user;
  final double averageScore;
  final int ratingCount;
  final String badgeTitle;
  final List<String> customTitles;

  factory AppLeaderboardUser.fromJson(Map<String, dynamic> json) {
    final titlesJson = (json['custom_titles'] as List<dynamic>? ?? <dynamic>[]);
    return AppLeaderboardUser(
      user: AppUser.fromJson(_normalizeUser(json['user'])),
      averageScore: _asDouble(json['average_score']),
      ratingCount: (json['rating_count'] ?? 0) as int,
      badgeTitle: (json['badge_title'] ?? '').toString(),
      customTitles:
          titlesJson.map((item) => item.toString()).toList(growable: false),
    );
  }
}

class AppRatingsPayload {
  const AppRatingsPayload({
    required this.leaderboard,
    required this.ratings,
  });

  final List<AppLeaderboardUser> leaderboard;
  final List<AppRatingEntry> ratings;

  factory AppRatingsPayload.fromJson(Map<String, dynamic> json) {
    final leaderboardJson =
        (json['leaderboard'] as List<dynamic>? ?? <dynamic>[]);
    final ratingsJson = (json['ratings'] as List<dynamic>? ?? <dynamic>[]);
    return AppRatingsPayload(
      leaderboard: leaderboardJson
          .map((item) => AppLeaderboardUser.fromJson(
              (item as Map).cast<String, dynamic>()))
          .toList(growable: false),
      ratings: ratingsJson
          .map((item) =>
              AppRatingEntry.fromJson((item as Map).cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}

class AppAmountStat {
  const AppAmountStat({
    required this.label,
    required this.amount,
  });

  final String label;
  final double amount;

  factory AppAmountStat.fromJson(Map<String, dynamic> json) {
    return AppAmountStat(
      label: (json['label'] ?? '').toString(),
      amount: _asDouble(json['amount']),
    );
  }
}

class AppCountStat {
  const AppCountStat({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  factory AppCountStat.fromJson(Map<String, dynamic> json,
      {String key = 'count'}) {
    return AppCountStat(
      label: (json['label'] ?? '').toString(),
      count: (json[key] ?? 0) as int,
    );
  }
}

class AppGroupStats {
  const AppGroupStats({
    required this.expenseCount,
    required this.proposalCount,
    required this.settlementCount,
    required this.spendByUser,
    required this.proposalVotes,
    required this.activityBreakdown,
    required this.topRatedUsers,
    this.selectedProposal,
  });

  final int expenseCount;
  final int proposalCount;
  final int settlementCount;
  final AppProposal? selectedProposal;
  final List<AppAmountStat> spendByUser;
  final List<AppCountStat> proposalVotes;
  final List<AppCountStat> activityBreakdown;
  final List<AppLeaderboardUser> topRatedUsers;

  factory AppGroupStats.fromJson(Map<String, dynamic> json) {
    final spendJson = (json['spend_by_user'] as List<dynamic>? ?? <dynamic>[]);
    final proposalVotesJson =
        (json['proposal_votes'] as List<dynamic>? ?? <dynamic>[]);
    final activityJson =
        (json['activity_breakdown'] as List<dynamic>? ?? <dynamic>[]);
    final topRatedJson =
        (json['top_rated_users'] as List<dynamic>? ?? <dynamic>[]);
    return AppGroupStats(
      expenseCount: (json['expense_count'] ?? 0) as int,
      proposalCount: (json['proposal_count'] ?? 0) as int,
      settlementCount: (json['settlement_count'] ?? 0) as int,
      selectedProposal: json['selected_proposal'] is Map<String, dynamic>
          ? AppProposal.fromJson(
              json['selected_proposal'] as Map<String, dynamic>)
          : json['selected_proposal'] is Map
              ? AppProposal.fromJson(
                  (json['selected_proposal'] as Map).cast<String, dynamic>())
              : null,
      spendByUser: spendJson
          .map((item) =>
              AppAmountStat.fromJson((item as Map).cast<String, dynamic>()))
          .toList(growable: false),
      proposalVotes: proposalVotesJson
          .map((item) => AppCountStat.fromJson(
              (item as Map).cast<String, dynamic>(),
              key: 'votes'))
          .toList(growable: false),
      activityBreakdown: activityJson
          .map((item) =>
              AppCountStat.fromJson((item as Map).cast<String, dynamic>()))
          .toList(growable: false),
      topRatedUsers: topRatedJson
          .map((item) => AppLeaderboardUser.fromJson(
              (item as Map).cast<String, dynamic>()))
          .toList(growable: false),
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
    final settlementsJson =
        (json['settlements'] as List<dynamic>? ?? <dynamic>[]);
    return BalancePayload(
      entries: balancesJson
          .map((entry) =>
              BalanceEntry.fromJson((entry as Map).cast<String, dynamic>()))
          .toList(growable: false),
      settlements: settlementsJson
          .map((entry) => SettlementSuggestion.fromJson(
              (entry as Map).cast<String, dynamic>()))
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

  factory FeedEventItem.fromJson(Map<String, dynamic> json,
      {String groupName = ''}) {
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

AppUser? _maybeUser(dynamic value) {
  final normalized = _normalizeUser(value);
  if (normalized.isEmpty) {
    return null;
  }
  return AppUser.fromJson(normalized);
}
