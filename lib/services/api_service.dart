import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bia_models.dart';

class ApiService {
  // 개발 환경: localhost
  // 프로덕션 환경: 실제 서버 URL로 변경
  static const String baseUrl = 'http://localhost:8000/api';

  Future<PredictionResult> predict(BiaInput input) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(input.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PredictionResult.fromJson(data);
      } else {
        throw Exception('예측 요청 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
