import 'dart:convert';
import 'dart:io';

import '../models/models.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PpmApiClient {
  PpmApiClient({String? baseUrl})
      : _baseUrl = baseUrl?.trim().isNotEmpty == true
            ? baseUrl!.trim()
            : defaultBaseUrl;

  static const defaultBaseUrl = String.fromEnvironment(
    'PPM_API_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  String _baseUrl;

  String get baseUrl => _baseUrl;

  void updateBaseUrl(String value) {
    _baseUrl = value.trim().isEmpty ? defaultBaseUrl : value.trim();
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final data = await _sendJson(
      'POST',
      '/auth/login',
      body: <String, dynamic>{
        'email': email,
        'password': password,
        'website': '',
        'form_started_at': 2,
      },
    );
    return AppUser.fromJson((data['user'] as Map).cast<String, dynamic>());
  }

  Future<AppUser> register({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String phoneNumber = '',
    String avatarUrl = '',
  }) async {
    final data = await _sendJson(
      'POST',
      '/auth/register',
      body: <String, dynamic>{
        'username': username,
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'avatar_url': avatarUrl,
        'website': '',
        'form_started_at': 2,
      },
    );
    return AppUser.fromJson((data['user'] as Map).cast<String, dynamic>());
  }

  Future<List<AppUser>> fetchUsers({String query = ''}) async {
    final normalized = query.trim();
    final path = normalized.isEmpty
        ? '/users'
        : '/users?q=${Uri.encodeQueryComponent(normalized)}';
    final data = await _sendJson('GET', path);
    return (data as List<dynamic>)
        .map((item) => AppUser.fromJson((item as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<List<AppContact>> fetchContacts(int userId) async {
    final data = await _sendJson('GET', '/users/$userId/contacts');
    return (data as List<dynamic>)
        .map((item) =>
            AppContact.fromJson((item as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<List<AppGroup>> fetchGroups(int userId) async {
    final data = await _sendJson('GET', '/users/$userId/groups');
    return (data as List<dynamic>)
        .map((item) => AppGroup.fromJson((item as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<List<AppGroup>> fetchInvitations(int userId) async {
    final data = await _sendJson('GET', '/users/$userId/invitations');
    return (data as List<dynamic>)
        .map((item) => AppGroup.fromJson((item as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<AppGroup> fetchGroup(int groupId) async {
    final data = await _sendJson('GET', '/groups/$groupId');
    return AppGroup.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<List<AppExpense>> fetchExpenses(int groupId) async {
    final data = await _sendJson('GET', '/groups/$groupId/expenses');
    return (data as List<dynamic>)
        .map((item) =>
            AppExpense.fromJson((item as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<BalancePayload> fetchBalances(int groupId) async {
    final data = await _sendJson('GET', '/groups/$groupId/balances');
    return BalancePayload.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<List<FeedEventItem>> fetchGroupFeed(int groupId,
      {String groupName = ''}) async {
    final data = await _sendJson('GET', '/groups/$groupId/feed');
    return (data as List<dynamic>)
        .map((item) => FeedEventItem.fromJson(
            (item as Map).cast<String, dynamic>(),
            groupName: groupName))
        .toList(growable: false);
  }

  Future<List<AppSettlement>> fetchSettlements(int groupId) async {
    final data = await _sendJson('GET', '/groups/$groupId/settlements');
    return (data as List<dynamic>)
        .map((item) =>
            AppSettlement.fromJson((item as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<List<AppProposal>> fetchProposals(int groupId) async {
    final data = await _sendJson('GET', '/groups/$groupId/proposals');
    return (data as List<dynamic>)
        .map((item) =>
            AppProposal.fromJson((item as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<AppRatingsPayload> fetchRatings(int groupId) async {
    final data = await _sendJson('GET', '/groups/$groupId/ratings');
    return AppRatingsPayload.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<AppGroupStats> fetchStats(int groupId) async {
    final data = await _sendJson('GET', '/groups/$groupId/stats');
    return AppGroupStats.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> createExpense({
    required int groupId,
    required int payerId,
    required String description,
    required double amount,
    required List<int> participantIds,
  }) async {
    await _sendJson(
      'POST',
      '/expenses',
      body: <String, dynamic>{
        'group_id': groupId,
        'payer_id': payerId,
        'description': description,
        'amount': amount,
        'participant_ids': participantIds,
      },
    );
  }

  Future<AppGroup> createGroup({
    required int creatorId,
    required String name,
    required String description,
    required List<int> memberIds,
    String endsAt = '',
    String autoCloseAction = 'none',
  }) async {
    final data = await _sendJson(
      'POST',
      '/groups',
      body: <String, dynamic>{
        'name': name,
        'description': description,
        'creator_id': creatorId,
        'member_ids': memberIds,
        'ends_at': endsAt,
        'auto_close_action': autoCloseAction,
      },
    );
    return AppGroup.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<AppGroup> addGroupMember({
    required int groupId,
    required int userId,
  }) async {
    final data = await _sendJson(
      'POST',
      '/groups/$groupId/members',
      body: <String, dynamic>{
        'user_id': userId,
      },
    );
    return AppGroup.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<AppGroup> acceptGroupInvitation({
    required int groupId,
    required int userId,
  }) async {
    final data = await _sendJson(
      'POST',
      '/groups/$groupId/members/$userId/accept',
    );
    return AppGroup.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Map<String, dynamic>> voteDeleteGroup({
    required int groupId,
    required int userId,
    String mode = 'majority',
  }) async {
    final data = await _sendJson(
      'POST',
      '/groups/$groupId/delete-vote',
      body: <String, dynamic>{
        'user_id': userId,
        'mode': mode,
      },
    );
    return (data as Map).cast<String, dynamic>();
  }

  Future<void> createSettlement({
    required int groupId,
    required int actorId,
    required int fromUserId,
    required int toUserId,
    required double amount,
    String notes = '',
  }) async {
    await _sendJson(
      'POST',
      '/groups/$groupId/settlements',
      body: <String, dynamic>{
        'actor_id': actorId,
        'from_user_id': fromUserId,
        'to_user_id': toUserId,
        'amount': amount,
        'notes': notes,
      },
    );
  }

  Future<void> confirmSettlement({
    required int settlementId,
    required int actorId,
  }) async {
    await _sendJson(
      'POST',
      '/settlements/$settlementId/confirm',
      body: <String, dynamic>{
        'actor_id': actorId,
      },
    );
  }

  Future<AppUser> updateProfile({
    required int userId,
    required String username,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String avatarUrl,
  }) async {
    final data = await _sendJson(
      'PATCH',
      '/users/$userId',
      body: <String, dynamic>{
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'avatar_url': avatarUrl,
      },
    );
    return AppUser.fromJson((data['user'] as Map).cast<String, dynamic>());
  }

  Future<void> saveContact({
    required int userId,
    required int contactUserId,
    String nickname = '',
  }) async {
    await _sendJson(
      'POST',
      '/users/$userId/contacts',
      body: <String, dynamic>{
        'contact_user_id': contactUserId,
        'nickname': nickname,
      },
    );
  }

  Future<void> createProposal({
    required int groupId,
    required int creatorId,
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
    await _sendJson(
      'POST',
      '/groups/$groupId/proposals',
      body: <String, dynamic>{
        'creator_id': creatorId,
        'title': title,
        'details': details,
        'activity_type': activityType,
        'availability_text': availabilityText,
        'provider_name': providerName,
        'provider_details': providerDetails,
        'provider_url': providerUrl,
        'payer_user_id': payerUserId,
        'payment_due_date': paymentDueDate,
        'scheduled_for_date': scheduledForDate,
        'vote_deadline': voteDeadline,
        'total_amount': totalAmount,
        'payment_method': paymentMethod,
        'confirmation_status': confirmationStatus,
        'is_shared_debt': isSharedDebt,
      },
    );
  }

  Future<void> voteProposal({
    required int proposalId,
    required int userId,
  }) async {
    await _sendJson(
      'POST',
      '/proposals/$proposalId/vote',
      body: <String, dynamic>{
        'user_id': userId,
      },
    );
  }

  Future<void> selectProposal({
    required int proposalId,
    required int userId,
  }) async {
    await _sendJson(
      'POST',
      '/proposals/$proposalId/select',
      body: <String, dynamic>{
        'user_id': userId,
      },
    );
  }

  Future<void> createRating({
    required int groupId,
    required int raterId,
    required int ratedUserId,
    required int score,
    required String title,
    String comment = '',
  }) async {
    await _sendJson(
      'POST',
      '/groups/$groupId/ratings',
      body: <String, dynamic>{
        'rater_id': raterId,
        'rated_user_id': ratedUserId,
        'score': score,
        'title': title,
        'comment': comment,
      },
    );
  }

  Future<dynamic> _sendJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, Uri.parse('$_baseUrl$path'));
      request.headers.contentType = ContentType.json;
      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final payload = await response.transform(utf8.decoder).join();
      final decoded = payload.isEmpty ? null : jsonDecode(payload);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded is Map<String, dynamic>
            ? (decoded['detail'] ?? 'No se pudo completar la solicitud.')
                .toString()
            : 'No se pudo completar la solicitud.';
        throw ApiException(message);
      }
      return decoded;
    } on SocketException {
      throw const ApiException(
          'No se pudo conectar con la API. Revisa la URL base y que el backend siga corriendo.');
    } finally {
      client.close(force: true);
    }
  }
}
