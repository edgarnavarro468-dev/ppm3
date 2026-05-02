import 'package:flutter/foundation.dart';

import '../../core/models/models.dart';
import '../../core/network/api_client.dart';

class AppState extends ChangeNotifier {
  AppState() : _api = PpmApiClient();

  final PpmApiClient _api;

  AppUser? currentUser;
  List<AppUser> users = const <AppUser>[];
  List<AppContact> contacts = const <AppContact>[];
  List<AppGroup> groups = const <AppGroup>[];
  List<AppGroup> invitations = const <AppGroup>[];
  AppGroup? activeGroup;
  List<AppExpense> expenses = const <AppExpense>[];
  BalancePayload? balances;
  List<AppSettlement> settlements = const <AppSettlement>[];
  List<AppProposal> proposals = const <AppProposal>[];
  AppRatingsPayload? ratings;
  AppGroupStats? stats;
  List<FeedEventItem> activeFeed = const <FeedEventItem>[];
  List<FeedEventItem> globalFeed = const <FeedEventItem>[];
  bool isBusy = false;
  int? activeGroupId;

  String get baseUrl => _api.baseUrl;
  bool get isAuthenticated => currentUser != null;

  void updateBaseUrl(String value) {
    _api.updateBaseUrl(value);
    notifyListeners();
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    await _runBusy(() async {
      currentUser = await _api.login(email: email, password: password);
      await _bootstrapInternal();
    });
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String phoneNumber = '',
    String avatarUrl = '',
  }) async {
    await _runBusy(() async {
      currentUser = await _api.register(
        username: username,
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        avatarUrl: avatarUrl,
      );
      await _bootstrapInternal();
    });
  }

  Future<void> bootstrap() async {
    await _runBusy(_bootstrapInternal);
  }

  Future<void> _bootstrapInternal() async {
    final user = currentUser;
    if (user == null) {
      return;
    }

    users = await _api.fetchUsers();
    contacts = await _api.fetchContacts(user.id);
    invitations = await _api.fetchInvitations(user.id);
    final rawGroups = await _api.fetchGroups(user.id);
    groups = await Future.wait(rawGroups.map(_hydrateGroupCard));
    groups = List<AppGroup>.from(groups)..sort((a, b) => b.id.compareTo(a.id));

    if (groups.isEmpty) {
      activeGroupId = null;
      activeGroup = null;
      expenses = const <AppExpense>[];
      balances = null;
      settlements = const <AppSettlement>[];
      proposals = const <AppProposal>[];
      ratings = null;
      stats = null;
      activeFeed = const <FeedEventItem>[];
      globalFeed = const <FeedEventItem>[];
      return;
    }

    activeGroupId = groups.any((group) => group.id == activeGroupId)
        ? activeGroupId
        : groups.first.id;
    globalFeed = _buildGlobalFeed(groups);
    await selectGroup(activeGroupId!, notify: false);
  }

  Future<void> selectGroup(int groupId, {bool notify = true}) async {
    activeGroupId = groupId;
    final group = await _api.fetchGroup(groupId);
    final expensesResult = await _api.fetchExpenses(groupId);
    final balancesResult = await _api.fetchBalances(groupId);
    final feedResult =
        await _api.fetchGroupFeed(groupId, groupName: group.name);
    final settlementsResult = await _api.fetchSettlements(groupId);
    final proposalsResult = await _api.fetchProposals(groupId);
    final ratingsResult = await _api.fetchRatings(groupId);
    final statsResult = await _api.fetchStats(groupId);
    final hydrated = group.copyWith(
      myNetBalance: _getUserNet(balancesResult),
      lastActivityMessage:
          feedResult.isNotEmpty ? feedResult.first.message : '',
    );

    activeGroup = hydrated;
    expenses = expensesResult;
    balances = balancesResult;
    settlements = settlementsResult;
    proposals = proposalsResult;
    ratings = ratingsResult;
    stats = statsResult;
    activeFeed = feedResult;
    groups = groups
        .map((item) => item.id == hydrated.id ? hydrated : item)
        .toList(growable: false);
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> createExpense({
    required int groupId,
    required int payerId,
    required String description,
    required double amount,
    required List<int> participantIds,
  }) async {
    await _runBusy(() async {
      await _api.createExpense(
        groupId: groupId,
        payerId: payerId,
        description: description,
        amount: amount,
        participantIds: participantIds,
      );
      activeGroupId = groupId;
      await _bootstrapInternal();
    });
  }

  Future<void> createGroup({
    required String name,
    required String description,
    required List<int> memberIds,
    String endsAt = '',
    String autoCloseAction = 'none',
  }) async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    await _runBusy(() async {
      final group = await _api.createGroup(
        creatorId: user.id,
        name: name,
        description: description,
        memberIds: memberIds,
        endsAt: endsAt,
        autoCloseAction: autoCloseAction,
      );
      activeGroupId = group.id;
      await _bootstrapInternal();
    });
  }

  Future<List<AppUser>> searchUsers(String query) async {
    final currentUserId = currentUser?.id;
    final results = await _api.fetchUsers(query: query);
    return results
        .where((user) => user.id != currentUserId)
        .toList(growable: false);
  }

  Future<void> addMemberToGroup({
    required int groupId,
    required int userId,
  }) async {
    await _runBusy(() async {
      final group = await _api.addGroupMember(groupId: groupId, userId: userId);
      activeGroupId = group.id;
      await _bootstrapInternal();
    });
  }

  Future<void> acceptInvitation(int groupId) async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    await _runBusy(() async {
      final group = await _api.acceptGroupInvitation(
        groupId: groupId,
        userId: user.id,
      );
      activeGroupId = group.id;
      await _bootstrapInternal();
    });
  }

  Future<Map<String, dynamic>> voteDeleteActiveGroup({
    String mode = 'majority',
  }) async {
    final user = currentUser;
    final groupId = activeGroupId;
    if (user == null || groupId == null) {
      return const <String, dynamic>{};
    }
    var result = <String, dynamic>{};
    await _runBusy(() async {
      result = await _api.voteDeleteGroup(
        groupId: groupId,
        userId: user.id,
        mode: mode,
      );
      activeGroupId = result['deleted'] == true ? null : groupId;
      await _bootstrapInternal();
    });
    return result;
  }

  Future<void> createSettlement({
    required int groupId,
    required int fromUserId,
    required int toUserId,
    required double amount,
    String notes = '',
  }) async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    await _runBusy(() async {
      await _api.createSettlement(
        groupId: groupId,
        actorId: user.id,
        fromUserId: fromUserId,
        toUserId: toUserId,
        amount: amount,
        notes: notes,
      );
      activeGroupId = groupId;
      await _bootstrapInternal();
    });
  }

  Future<void> confirmSettlement(int settlementId) async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    await _runBusy(() async {
      await _api.confirmSettlement(
        settlementId: settlementId,
        actorId: user.id,
      );
      await _bootstrapInternal();
    });
  }

  Future<void> updateProfile({
    required String username,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String avatarUrl,
  }) async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    await _runBusy(() async {
      currentUser = await _api.updateProfile(
        userId: user.id,
        username: username,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        avatarUrl: avatarUrl,
      );
      await _bootstrapInternal();
    });
  }

  Future<void> saveContact({
    required int contactUserId,
    String nickname = '',
  }) async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    await _runBusy(() async {
      await _api.saveContact(
        userId: user.id,
        contactUserId: contactUserId,
        nickname: nickname,
      );
      contacts = await _api.fetchContacts(user.id);
    });
  }

  Future<void> createProposal({
    required int groupId,
    required String title,
    required String details,
    required String activityType,
    required double totalAmount,
    String availabilityText = '',
    String providerName = '',
    String providerDetails = '',
    String providerUrl = '',
    int? payerUserId,
    String paymentDueDate = '',
    String scheduledForDate = '',
    String voteDeadline = '',
    String paymentMethod = '',
    String confirmationStatus = 'pendiente',
    bool isSharedDebt = true,
  }) async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    await _runBusy(() async {
      await _api.createProposal(
        groupId: groupId,
        creatorId: user.id,
        title: title,
        details: details,
        activityType: activityType,
        totalAmount: totalAmount,
        availabilityText: availabilityText,
        providerName: providerName,
        providerDetails: providerDetails,
        providerUrl: providerUrl,
        payerUserId: payerUserId,
        paymentDueDate: paymentDueDate,
        scheduledForDate: scheduledForDate,
        voteDeadline: voteDeadline,
        paymentMethod: paymentMethod,
        confirmationStatus: confirmationStatus,
        isSharedDebt: isSharedDebt,
      );
      activeGroupId = groupId;
      await _bootstrapInternal();
    });
  }

  Future<void> voteProposal(int proposalId) async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    await _runBusy(() async {
      await _api.voteProposal(
        proposalId: proposalId,
        userId: user.id,
      );
      await _bootstrapInternal();
    });
  }

  Future<void> selectProposal(int proposalId) async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    await _runBusy(() async {
      await _api.selectProposal(
        proposalId: proposalId,
        userId: user.id,
      );
      await _bootstrapInternal();
    });
  }

  Future<void> createRating({
    required int groupId,
    required int ratedUserId,
    required int score,
    required String title,
    String comment = '',
  }) async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    await _runBusy(() async {
      await _api.createRating(
        groupId: groupId,
        raterId: user.id,
        ratedUserId: ratedUserId,
        score: score,
        title: title,
        comment: comment,
      );
      activeGroupId = groupId;
      await _bootstrapInternal();
    });
  }

  void logout() {
    currentUser = null;
    users = const <AppUser>[];
    contacts = const <AppContact>[];
    groups = const <AppGroup>[];
    invitations = const <AppGroup>[];
    activeGroup = null;
    expenses = const <AppExpense>[];
    balances = null;
    settlements = const <AppSettlement>[];
    proposals = const <AppProposal>[];
    ratings = null;
    stats = null;
    activeFeed = const <FeedEventItem>[];
    globalFeed = const <FeedEventItem>[];
    activeGroupId = null;
    notifyListeners();
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    isBusy = true;
    notifyListeners();
    try {
      await action();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<AppGroup> _hydrateGroupCard(AppGroup group) async {
    try {
      final balancesResult = await _api.fetchBalances(group.id);
      final feedResult =
          await _api.fetchGroupFeed(group.id, groupName: group.name);
      return group.copyWith(
        myNetBalance: _getUserNet(balancesResult),
        lastActivityMessage:
            feedResult.isNotEmpty ? feedResult.first.message : '',
      );
    } catch (_) {
      return group;
    }
  }

  List<FeedEventItem> _buildGlobalFeed(List<AppGroup> source) {
    final items = <FeedEventItem>[];
    for (final group in source) {
      if (group.lastActivityMessage.trim().isEmpty) {
        continue;
      }
      items.add(
        FeedEventItem(
          message: group.lastActivityMessage,
          createdAt: null,
          groupName: group.name,
        ),
      );
    }
    return items;
  }

  double _getUserNet(BalancePayload payload) {
    final id = currentUser?.id;
    if (id == null) {
      return 0;
    }
    final entry = payload.entries.cast<BalanceEntry?>().firstWhere(
          (item) => item?.user.id == id,
          orElse: () => null,
        );
    return entry?.net ?? 0;
  }
}
