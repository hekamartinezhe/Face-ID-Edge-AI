import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Reemplazar con la IP del server de Fer o q
  final String baseUrl = "http://100.119.64.47:8000";

  Future<Map<String, dynamic>> getServerStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/status'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception("Error al conectar con el servidor");
      }
    } catch (e) {
      return {"status": "offline", "authorized": false};
    }
  }

  Future<bool> registerAttendance(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/attendance'),
      body: json.encode(data),
      headers: {"Content-Type": "application/json"},
    );
    return response.statusCode == 201;
  }
}
