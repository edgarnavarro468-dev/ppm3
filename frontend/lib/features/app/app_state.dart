import 'package:flutter/foundation.dart';

import '../../core/models/models.dart';
import '../../core/network/api_client.dart';

class AppState extends ChangeNotifier {
  AppState() : _api = PpmApiClient();

  final PpmApiClient _api;

  AppUser? currentUser;
  List<AppUser> users = const <AppUser>[];
  List<AppGroup> groups = const <AppGroup>[];
  AppGroup? activeGroup;
  List<AppExpense> expenses = const <AppExpense>[];
  BalancePayload? balances;
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
  }) async {
    await _runBusy(() async {
      currentUser = await _api.register(
        username: username,
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
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
    final rawGroups = await _api.fetchGroups(user.id);
    groups = await Future.wait(rawGroups.map(_hydrateGroupCard));
    groups = List<AppGroup>.from(groups)
      ..sort((a, b) => b.id.compareTo(a.id));

    if (groups.isEmpty) {
      activeGroupId = null;
      activeGroup = null;
      expenses = const <AppExpense>[];
      balances = null;
      activeFeed = const <FeedEventItem>[];
      globalFeed = const <FeedEventItem>[];
      return;
    }

    activeGroupId = groups.any((group) => group.id == activeGroupId) ? activeGroupId : groups.first.id;
    globalFeed = _buildGlobalFeed(groups);
    await selectGroup(activeGroupId!, notify: false);
  }

  Future<void> selectGroup(int groupId, {bool notify = true}) async {
    activeGroupId = groupId;
    final group = await _api.fetchGroup(groupId);
    final expensesResult = await _api.fetchExpenses(groupId);
    final balancesResult = await _api.fetchBalances(groupId);
    final feedResult = await _api.fetchGroupFeed(groupId, groupName: group.name);
    final hydrated = group.copyWith(
      myNetBalance: _getUserNet(balancesResult),
      lastActivityMessage: feedResult.isNotEmpty ? feedResult.first.message : '',
    );

    activeGroup = hydrated;
    expenses = expensesResult;
    balances = balancesResult;
    activeFeed = feedResult;
    groups = groups.map((item) => item.id == hydrated.id ? hydrated : item).toList(growable: false);
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
      );
      activeGroupId = group.id;
      await _bootstrapInternal();
    });
  }

  void logout() {
    currentUser = null;
    users = const <AppUser>[];
    groups = const <AppGroup>[];
    activeGroup = null;
    expenses = const <AppExpense>[];
    balances = null;
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
      final feedResult = await _api.fetchGroupFeed(group.id, groupName: group.name);
      return group.copyWith(
        myNetBalance: _getUserNet(balancesResult),
        lastActivityMessage: feedResult.isNotEmpty ? feedResult.first.message : '',
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
