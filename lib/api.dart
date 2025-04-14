import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import './model.dart';

const rootURL = 'slajdy.swro.ch';

class ApiError implements Exception {}

Uri apiURL(String path, [Map<String, dynamic>? params]) {
  return Uri.https(rootURL, path, params);
}

Future<Map<String, String>> addAccessToken(
    [Map<String, String> headers = const {}]) async {
  final storage = FlutterSecureStorage();
  final accessToken = await storage.read(key: 'accessToken') ?? '';

  if (accessToken.isNotEmpty) {
    headers = Map<String, String>.from(headers);
    headers['Authorization'] = 'Bearer $accessToken';
  }

  return headers;
}

Future<List<Song>> getSongs(String query) async {
  final response = await http.get(
    apiURL('v2/songs', {'query': query}),
    headers: await addAccessToken(),
  );

  if (response.statusCode != 200) {
    throw ApiError();
  }

  final json = jsonDecode(response.body) as List;

  return json.map((itemJson) => Song.fromJson(itemJson)).toList();
}

Future<List<String>> getLyrics(String songId, {bool raw = false}) async {
  final response = await http.get(
    apiURL("v2/lyrics/$songId", {'raw': raw ? '1' : null}),
    headers: await addAccessToken(),
  );

  if (response.statusCode != 200) {
    throw ApiError();
  }

  final json = jsonDecode(response.body) as List;

  return json.map((itemJson) => itemJson.toString()).toList();
}

Future<DeckResponse> postDeck(deckRequest) async {
  final response = await http.post(
    apiURL('v2/deck'),
    headers: await addAccessToken({
      'Content-Type': 'application/json; charset=UTF-8',
    }),
    body: jsonEncode(deckRequest),
  );
  final deckResponse = DeckResponse.fromJson(jsonDecode(response.body));

  return deckResponse;
}

Future<BootstrapResponse> getBootstrap() async {
  final response = await http.get(apiURL('v2/bootstrap'));

  if (response.statusCode != 200) {
    throw ApiError();
  }

  return BootstrapResponse.fromJson(jsonDecode(response.body));
}

Future<Liturgy> getLiturgy(DateTime date) async {
  final dateString = date.toIso8601String().substring(0, 10);
  final response = await http.get(apiURL("v2/liturgy/$dateString"));

  if (response.statusCode != 200) {
    throw ApiError();
  }

  return Liturgy.fromJson(jsonDecode(response.body));
}

class AuthResponse {
  final String token;
  final String refreshToken;
  final String name;

  AuthResponse(
      {required this.token, required this.refreshToken, required this.name});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'],
      refreshToken: json['refreshToken'],
      name: json['name'],
    );
  }
}

Future<void> storeAuthResponse(AuthResponse authResponse) async {
  final storage = FlutterSecureStorage();
  await storage.write(key: 'accessToken', value: authResponse.token);
  await storage.write(key: 'refreshToken', value: authResponse.refreshToken);
}

Future<AuthResponse> postAuthGoogle(String idToken) async {
  final response = await http.post(
    apiURL('v2/auth/google'),
    body: jsonEncode({'idToken': idToken}),
  );

  if (response.statusCode != 200 && response.statusCode != 201) {
    print("RESPONSE: ${response.body}");
    throw ApiError();
  }

  final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
  await storeAuthResponse(authResponse);

  return authResponse;
}

Future<AuthResponse> postAuthRefresh() async {
  final storage = FlutterSecureStorage();
  final refreshToken = await storage.read(key: 'refreshToken');

  if (refreshToken == null) {
    throw ApiError();
  }

  final jsonBody = jsonEncode({'refreshToken': refreshToken});
  final response = await http.post(
    apiURL('v2/auth/refresh'),
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonBody,
  );

  if (response.statusCode != 200 && response.statusCode != 201) {
    throw ApiError();
  }

  final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
  await storeAuthResponse(authResponse);

  return authResponse;
}
