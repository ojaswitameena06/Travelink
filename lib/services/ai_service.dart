import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static const String _proxyUrl =
      'https://red-haze-5b8dtravelink-ai-proxy.ojaswita06.workers.dev';

  static Future<String> getTravelAdvice(String userPrompt) async {
    try {
      final response = await http.post(
        Uri.parse(_proxyUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': userPrompt}),
      );

      if (response.statusCode != 200) {
        return "Sorry, I couldn't process that right now. Please try again.";
      }

      final data = jsonDecode(response.body);
      return data['reply'] ?? "Sorry, I couldn't process that. Please try again.";
    } catch (e) {
      return "Sorry, something went wrong. Please check your connection and try again.";
    }
  }

  static Future<List<Map<String, dynamic>>> getPersonalizedPackages(
    List<String> categories, {
    int count = 6,
  }) async {
    final response = await http.post(
      Uri.parse('$_proxyUrl/packages'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'categories': categories, 'count': count}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to generate packages');
    }

    final data = jsonDecode(response.body);
    final List<dynamic> rawPackages = data['packages'] ?? [];
    return rawPackages.map((p) => Map<String, dynamic>.from(p)).toList();
  }

  /// Returns {planId: {'reason': ..., 'icebreaker': ...}} for the candidate plans.
  static Future<Map<String, Map<String, String>>> getBuddyInsights(
    Map<String, dynamic> myPlan,
    List<Map<String, dynamic>> candidates,
  ) async {
    final response = await http.post(
      Uri.parse('$_proxyUrl/buddy'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'myPlan': myPlan, 'candidates': candidates}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get buddy insights');
    }

    final data = jsonDecode(response.body);
    final List<dynamic> raw = data['insights'] ?? [];
    final result = <String, Map<String, String>>{};
    for (final item in raw) {
      final m = Map<String, dynamic>.from(item);
      final id = m['id']?.toString();
      if (id == null) continue;
      result[id] = {
        'reason': m['reason']?.toString() ?? '',
        'icebreaker': m['icebreaker']?.toString() ?? '',
      };
    }
    return result;
  }
}