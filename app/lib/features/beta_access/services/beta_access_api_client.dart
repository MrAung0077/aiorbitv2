import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class BetaAccessApiClient {
  BetaAccessApiClient({
    required String baseUrl,
    required String betaAccessToken,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
  }) : _baseUri = Uri.tryParse(baseUrl.trim()),
       _betaAccessToken = betaAccessToken.trim(),
       _httpClient = httpClient ?? http.Client();

  final Uri? _baseUri;
  final String _betaAccessToken;
  final http.Client _httpClient;
  final Duration timeout;

  Future<BetaActivationResult> activate({
    required String inviteCode,
    required String activationId,
  }) async {
    final baseUri = _baseUri;
    if (baseUri == null ||
        (baseUri.scheme != 'https' && baseUri.scheme != 'http') ||
        baseUri.host.isEmpty ||
        _betaAccessToken.isEmpty) {
      throw const BetaAccessException(BetaAccessFailure.unavailable);
    }

    final response = await _post(
      baseUri.resolve('/v1/beta/activate'),
      <String, Object?>{
        'inviteCode': inviteCode.trim(),
        'activationId': activationId.trim(),
      },
    );
    final decoded = _decodeObject(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final code = decoded?['error'] is Map<String, dynamic>
          ? (decoded!['error'] as Map<String, dynamic>)['code'] as String?
          : null;
      throw BetaAccessException(_failureFor(code, response.statusCode));
    }

    final deviceSession = decoded?['deviceSession'];
    if (deviceSession is! String || deviceSession.trim().isEmpty) {
      throw const BetaAccessException(BetaAccessFailure.unavailable);
    }

    return BetaActivationResult(
      deviceSession: deviceSession.trim(),
      recoveryCode: decoded?['recoveryCode'] as String?,
    );
  }

  Future<http.Response> _post(Uri uri, Map<String, Object?> body) async {
    try {
      return await _httpClient
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'X-Ovexiq-Beta-Token': _betaAccessToken,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const BetaAccessException(BetaAccessFailure.unavailable);
    } on SocketException {
      throw const BetaAccessException(BetaAccessFailure.unavailable);
    } on HandshakeException {
      throw const BetaAccessException(BetaAccessFailure.unavailable);
    } on http.ClientException {
      throw const BetaAccessException(BetaAccessFailure.unavailable);
    }
  }

  Map<String, dynamic>? _decodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  BetaAccessFailure _failureFor(String? code, int statusCode) {
    if (code == 'invalid_beta_invite') {
      return BetaAccessFailure.invalidInvite;
    }
    if (code == 'installation_revoked' || code == 'account_disabled') {
      return BetaAccessFailure.revoked;
    }
    if (statusCode == 401 || statusCode == 403) {
      return BetaAccessFailure.invalidInvite;
    }
    return BetaAccessFailure.unavailable;
  }

  void close() => _httpClient.close();
}

class BetaActivationResult {
  const BetaActivationResult({required this.deviceSession, this.recoveryCode});

  final String deviceSession;
  final String? recoveryCode;
}

enum BetaAccessFailure { invalidInvite, revoked, unavailable }

class BetaAccessException implements Exception {
  const BetaAccessException(this.failure);

  final BetaAccessFailure failure;

  String get userMessage => switch (failure) {
    BetaAccessFailure.invalidInvite =>
      'သင်ထည့်သွင်းသော beta invite code မမှန်ပါ။ ပြန်စစ်ပြီး ထပ်မံကြိုးစားပါ။',
    BetaAccessFailure.revoked => 'ဤစက်၏ beta အသုံးပြုခွင့်ကို ပိတ်ထားပါသည်။',
    BetaAccessFailure.unavailable =>
      'Beta အသုံးပြုခွင့်ကို ယခုအချိန်တွင် အတည်ပြု၍ မရသေးပါ။ ခဏအကြာ ထပ်မံကြိုးစားပါ။',
  };

  @override
  String toString() => userMessage;
}
