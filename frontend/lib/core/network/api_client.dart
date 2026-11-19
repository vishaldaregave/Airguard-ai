import 'package:dio/dio.dart';
import '../constants/api_constants.dart';

class ApiClient {
  final Dio dio;

  // Default cryptographic HMAC-SHA256 JWT for 'default_user' with validated issuer and audience
  static const String defaultJwtToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkZWZhdWx0X3VzZXIiLCJ1c2VyX2lkIjoiZGVmYXVsdF91c2VyIiwiaWF0IjoxNzk0ODM5MzU0LCJleHAiOjIxMTAxOTkzNTQsImlzcyI6ImFpcmd1YXJkLWFpLWF1dGgiLCJhdWQiOiJhaXJndWFyZC1haS1jbGllbnQifQ.QoxttHjCeTYVK8D6isci2uYiu0g6L41exHx3c8-Wihk';

  ApiClient({String? baseUrl})
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? ApiConstants.resolvedBaseUrl,
            connectTimeout: ApiConstants.connectTimeout,
            receiveTimeout: ApiConstants.receiveTimeout,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'X-User-ID': 'default_user',
              'Authorization': 'Bearer $defaultJwtToken',
            },
          ),
        ) {
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: false,
        requestBody: true,
        responseHeader: false,
        responseBody: false,
        error: true,
      ),
    );
  }

  void setAuthToken(String token, {String? userId}) {
    dio.options.headers['Authorization'] = 'Bearer $token';
    if (userId != null) {
      dio.options.headers['X-User-ID'] = userId;
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.get<T>(path, queryParameters: queryParameters, options: options);
    } on DioException {
      rethrow;
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    try {
      return await dio.post<T>(path, data: data, options: options);
    } on DioException {
      rethrow;
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    try {
      return await dio.put<T>(path, data: data, options: options);
    } on DioException {
      rethrow;
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    try {
      return await dio.patch<T>(path, data: data, options: options);
    } on DioException {
      rethrow;
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    try {
      return await dio.delete<T>(path, data: data, options: options);
    } on DioException {
      rethrow;
    }
  }
}
