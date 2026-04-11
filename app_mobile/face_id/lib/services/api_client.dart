import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/recognition_result.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  // Por defecto uso tu túnel ngrok; puedes cambiarlo en tiempo de ejecución.
  String baseUrl = 'https://52f9-177-229-178-140.ngrok-free.app';
  bool serverOnline = false;
  Map<String, dynamic>? serverInfo;

  /// Consulta el endpoint `/status` y guarda el estado en memoria.
  Future<bool> checkStatus({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final uri = Uri.parse('$baseUrl/status');
      final resp = await http.get(uri).timeout(timeout);
      if (resp.statusCode != 200) {
        serverOnline = false;
        serverInfo = null;
        return false;
      }
      final Map<String, dynamic> data = jsonDecode(resp.body);
      serverInfo = data;
      serverOnline = (data['status'] == 'online');
      return serverOnline;
    } catch (e) {
      serverOnline = false;
      serverInfo = null;
      return false;
    }
  }

  /// Envía un vector JSON (legacy). Devuelve un RecognitionResult genérico.
  Future<RecognitionResult> sendVector(List<double> vector, {String? deviceId, String? token}) async {
    final url = Uri.parse('$baseUrl/recognize');
    final body = jsonEncode({
      'vector': vector,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'device_id': deviceId,
    });

    final headers = {'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final resp = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) {
      return RecognitionResult(
        status: 'error',
        match: false,
        assistance: false,
        message: 'HTTP ${resp.statusCode}',
      );
    }

    final Map<String, dynamic> data = jsonDecode(resp.body);
    return RecognitionResult.fromJson(data);
  }

  /// Envía una imagen (multipart/form-data) al endpoint `/asistence` de tu API.
  /// El servidor responde con JSON: { "resultado": "reconocido"|"desconocido", ... }
  Future<RecognitionResult> sendImageForAssistance(Uint8List imageBytes, {String? filename, String? token}) async {
    final uri = Uri.parse('$baseUrl/asistence');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: filename ?? 'frame.jpg'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    final streamed = await request.send().timeout(const Duration(seconds: 15));
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode != 200) {
      return RecognitionResult(
        status: 'error',
        match: false,
        assistance: false,
        message: 'HTTP ${resp.statusCode}',
      );
    }

    final Map<String, dynamic> data = jsonDecode(resp.body);

    // Manejar formato de tu API
    if (data.containsKey('error')) {
      return RecognitionResult(
        status: 'error',
        match: false,
        assistance: false,
        message: data['error'] as String?,
      );
    }

    final resultado = data['resultado'] as String?;
    if (resultado == 'reconocido') {
      return RecognitionResult(
        status: 'ok',
        match: true,
        label: data['nombre'] as String?,
        confidence: (data['confianza'] as num?)?.toDouble(),
        assistance: false,
        message: data['tiempo_procesamiento_ms'] != null
            ? 'tiempo_ms: ${data['tiempo_procesamiento_ms']}'
            : null,
      );
    }

    // desconocido
    return RecognitionResult(
      status: 'ok',
      match: false,
      label: null,
      confidence: (data['confianza'] as num?)?.toDouble(),
      assistance: false,
      message: data['tiempo_procesamiento_ms'] != null ? 'tiempo_ms: ${data['tiempo_procesamiento_ms']}' : null,
    );
  }

  /// Registra una imagen junto con el nombre en `/register` usando multipart/form-data.
  Future<RecognitionResult> sendRegister(Uint8List imageBytes, String nombre, {String? filename, String? token}) async {
    final uri = Uri.parse('$baseUrl/register');
    final request = http.MultipartRequest('POST', uri);
    request.fields['nombre'] = nombre;
    request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: filename ?? 'frame.jpg'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    final streamed = await request.send().timeout(const Duration(seconds: 15));
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode != 200) {
      return RecognitionResult(
        status: 'error',
        match: false,
        assistance: false,
        message: 'HTTP ${resp.statusCode}',
      );
    }

    final Map<String, dynamic> data = jsonDecode(resp.body);
    // FastAPI register returns {"mensaje":..., "status":"registrado"}
    return RecognitionResult(
      status: data['status'] as String? ?? 'ok',
      match: true,
      label: data['mensaje'] as String?,
      confidence: null,
      assistance: false,
      message: data['mensaje'] as String?,
    );
  }
}
