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
      : _baseUrl = baseUrl?.trim().isNotEmpty == true ? baseUrl!.trim() : defaultBaseUrl;

  static const defaultBaseUrl = 'http://10.0.2.2:8000';

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
        'phone_number': '',
        'avatar_url': '',
        'website': '',
        'form_started_at': 2,
      },
    );
    return AppUser.fromJson((data['user'] as Map).cast<String, dynamic>());
  }

  Future<List<AppUser>> fetchUsers() async {
    final data = await _sendJson('GET', '/users');
    return (data as List<dynamic>)
        .map((item) => AppUser.fromJson((item as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<List<AppGroup>> fetchGroups(int userId) async {
    final data = await _sendJson('GET', '/users/$userId/groups');
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
        .map((item) => AppExpense.fromJson((item as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<BalancePayload> fetchBalances(int groupId) async {
    final data = await _sendJson('GET', '/groups/$groupId/balances');
    return BalancePayload.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<List<FeedEventItem>> fetchGroupFeed(int groupId, {String groupName = ''}) async {
    final data = await _sendJson('GET', '/groups/$groupId/feed');
    return (data as List<dynamic>)
        .map((item) => FeedEventItem.fromJson((item as Map).cast<String, dynamic>(), groupName: groupName))
        .toList(growable: false);
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
  }) async {
    final data = await _sendJson(
      'POST',
      '/groups',
      body: <String, dynamic>{
        'name': name,
        'description': description,
        'creator_id': creatorId,
        'member_ids': memberIds,
        'ends_at': '',
        'auto_close_action': 'none',
      },
    );
    return AppGroup.fromJson((data as Map).cast<String, dynamic>());
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
            ? (decoded['detail'] ?? 'No se pudo completar la solicitud.').toString()
            : 'No se pudo completar la solicitud.';
        throw ApiException(message);
      }
      return decoded;
    } on SocketException {
      throw const ApiException('No se pudo conectar con la API. Revisa la URL base y que el backend siga corriendo.');
    } finally {
      client.close(force: true);
    }
  }
}
