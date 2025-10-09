import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import './model.dart';

const rootURL = 'https://api.psal.lt/';

class ApiError implements Exception {}

class ApiClient {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  bool _isRefreshing = false;

  ApiClient()
      : _dio = Dio(BaseOptions(
          baseUrl: rootURL,
          contentType: 'application/json; charset=UTF-8',
        )),
        _storage = const FlutterSecureStorage() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final accessToken = await _storage.read(key: 'accessToken') ?? '';
        if (accessToken.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $accessToken';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 &&
            error.response?.data['error'] == 'token expired' &&
            !_isRefreshing &&
            await _storage.containsKey(key: 'refreshToken')) {
          try {
            _isRefreshing = true;
            await _refreshToken();
            _isRefreshing = false;

            // Retry the original request
            final opts = Options(
              method: error.requestOptions.method,
              headers: error.requestOptions.headers,
            );
            final response = await _dio.request(
              error.requestOptions.path,
              options: opts,
              data: error.requestOptions.data,
              queryParameters: error.requestOptions.queryParameters,
            );
            return handler.resolve(response);
          } catch (e) {
            _isRefreshing = false;
            return handler.reject(error);
          }
        }
        return handler.next(error);
      },
    ));
  }

  Future<void> _refreshToken() async {
    final refreshToken = await _storage.read(key: 'refreshToken');
    if (refreshToken == null) {
      throw ApiError();
    }

    final response = await _dio.post(
      '/v2/auth/refresh',
      data: {'refreshToken': refreshToken},
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      storeAuthResponse(null);
      throw ApiError();
    }

    final authResponse = AuthResponse.fromJson(response.data);
    await storeAuthResponse(authResponse);
  }

  Future<Response> get(String path, {Map<String, dynamic>? params}) async {
    return _dio.get(path, queryParameters: params);
  }

  Future<Response> post(String path,
      {Map<String, dynamic>? params, Object? data, Options? options}) async {
    return _dio.post(path,
        queryParameters: params, data: data, options: options);
  }

  Future<Response> put(String path,
      {Map<String, dynamic>? params, Object? data, Options? options}) async {
    return _dio.put(path,
        queryParameters: params, data: data, options: options);
  }

  Future<Response> delete(String path,
      {Map<String, dynamic>? params, Object? data}) async {
    return _dio.delete(path, queryParameters: params, data: data);
  }

  void close() {
    _dio.close();
  }
}

final apiClient = ApiClient();

Future<List<Song>> getSongs(String query, {String? teamId}) async {
  final response = await apiClient.get('v2/songs', params: {
    'query': query,
    'teamId': teamId,
  });

  if (response.statusCode != 200) {
    throw ApiError();
  }

  return (response.data as List)
      .map((itemJson) => Song.fromJson(itemJson))
      .toList();
}

class PaginatedResponse<T> {
  final List<T> items;
  final int total;

  PaginatedResponse({required this.items, required this.total});
}

Future<PaginatedResponse<Song>> getSongsPaginated(String query,
    {required int limit, required int offset, String? teamId}) async {
  final response = await apiClient.get('v2/songs', params: {
    'query': query,
    'limit': limit,
    'offset': offset,
    'teamId': teamId,
  });

  if (response.statusCode != 200) {
    throw ApiError();
  }

  return PaginatedResponse(
    items: (response.data['items'] as List)
        .map((itemJson) => Song.fromJson(itemJson))
        .toList(),
    total: response.data['total'],
  );
}

Future<Song> getSong(String id) async {
  final response = await apiClient.get("v2/songs/$id");
  return Song.fromJson(response.data);
}

Future<List<String>> getLyrics(String songId, {bool raw = false}) async {
  final response = await apiClient.get(
    "v2/lyrics/$songId",
    params: {'raw': raw ? '1' : null},
  );

  if (response.statusCode != 200) {
    throw ApiError();
  }

  return (response.data as List).map((item) => item.toString()).toList();
}

Future<DeckResponse> postDeck(deckRequest) async {
  final response = await apiClient.post('v2/deck', data: deckRequest);
  return DeckResponse.fromJson(response.data);
}

Future<BootstrapResponse> getBootstrap() async {
  final response = await apiClient.get('v2/bootstrap');

  if (response.statusCode != 200) {
    throw ApiError();
  }

  return BootstrapResponse.fromJson(response.data);
}

Future<Liturgy> getLiturgy(DateTime date) async {
  final dateString = date.toIso8601String().substring(0, 10);
  final response = await apiClient.get("v2/liturgy/$dateString");

  if (response.statusCode != 200) {
    throw ApiError();
  }

  return Liturgy.fromJson(response.data);
}

Future<AuthResponse> postAuthGoogle(String idToken) async {
  final response = await apiClient.post(
    'v2/auth/google',
    data: {'idToken': idToken},
  );

  if (response.statusCode != 200 && response.statusCode != 201) {
    throw ApiError();
  }

  final authResponse = AuthResponse.fromJson(response.data);
  await storeAuthResponse(authResponse);

  return authResponse;
}

Future<void> deleteAuthRefresh() async {
  final storage = FlutterSecureStorage();
  final refreshToken = await storage.read(key: 'refreshToken');
  if (refreshToken == null) {
    return;
  }

  await apiClient.delete(
    'v2/auth/refresh',
    data: {
      'refreshToken': refreshToken,
    },
  );

  await storeAuthResponse(null);
}

Future<User> getAuthMe() async {
  final response = await apiClient.get('v2/users/me');
  return User.fromJson(response.data);
}

Future<NonceResponse> postAuthNonce() async {
  final response = await apiClient.post('v2/auth/nonce');
  return NonceResponse.fromJson(response.data);
}

Future<void> storeAuthResponse(AuthResponse? authResponse) async {
  final storage = FlutterSecureStorage();
  if (authResponse == null) {
    await storage.deleteAll();
  } else {
    await storage.write(key: 'accessToken', value: authResponse.token);
    await storage.write(key: 'refreshToken', value: authResponse.refreshToken);
  }
}

Future<List<Team>> getTeams() async {
  final response = await apiClient.get('v2/teams');
  return (response.data as List)
      .map((itemJson) => Team.fromJson(itemJson))
      .toList();
}

Future<Team> postTeam(String name) async {
  final response = await apiClient.post('v2/teams', data: {'name': name});
  return Team.fromJson(response.data);
}

Future<TeamInvitation> postTeamInvite(String teamId) async {
  final response = await apiClient.post('v2/teams/$teamId/invite');
  return TeamInvitation.fromJson(response.data);
}

Future<Team> postJoinTeam(String invitationToken) async {
  final response =
      await apiClient.post('v2/teams/join', data: {'token': invitationToken});
  return Team.fromJson(response.data);
}
