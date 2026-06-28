import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // When running as Flutter web served by nginx, calls go to the same origin
  // and nginx proxies /api/ to the Go API service inside the cluster.
  // Override at build time with: --dart-define=API_BASE_URL=http://localhost:8080
  static String get _base {
    const env = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    return env.isEmpty ? '/api/v1' : '$env/api/v1';
  }

  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<Map<String, dynamic>> register(
      String email, String password) async {
    final res = await http.post(
      Uri.base.resolve('$_base/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 201) {
      throw Exception(body['error'] ?? 'Registration failed');
    }
    return body;
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final res = await http.post(
      Uri.base.resolve('$_base/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? 'Login failed');
    }
    return body;
  }

  static Future<Map<String, dynamic>> getProgress() async {
    final token = await _token();
    final res = await http.get(
      Uri.base.resolve('$_base/progress'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) throw Exception('Failed to load progress');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> updateProgress(
      int phaseIndex, int itemIndex, bool completed) async {
    final token = await _token();
    await http.put(
      Uri.base.resolve('$_base/progress'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'phase_index': phaseIndex,
        'item_index': itemIndex,
        'completed': completed,
      }),
    );
  }

  static Future<void> saveToken(String token, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setString('user_email', email);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_email');
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_email');
  }
}
