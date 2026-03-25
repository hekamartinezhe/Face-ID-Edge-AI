import 'dart:math';

import '../models/user_model.dart';
import '../models/recognition_result.dart';
import 'api_client.dart';
import 'local_storage_service.dart';

class RecognitionService {
  RecognitionService._();
  static final RecognitionService instance = RecognitionService._();
  // Si true, permite un "bypass" (match permitido) cuando no hay base local
  // y la API no está disponible. Úsalo con precaución en entornos de prueba.
  bool enableBypass = true;

  double _cosineSimilarity(List<double> a, List<double> b) {
    final minLen = min(a.length, b.length);
    double dot = 0.0;
    double na = 0.0;
    double nb = 0.0;
    for (var i = 0; i < minLen; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na == 0 || nb == 0) return 0.0;
    return dot / (sqrt(na) * sqrt(nb));
  }

  Future<RecognitionResult> recognize(List<double> vector,
      {double threshold = 0.8, String? deviceId, String? token}) async {
    // 1) Intentar emparejar localmente
    final users = await LocalStorageService.instance.loadAll();
    // Si no hay usuarios locales y el bypass está activado, devolver resultado de bypass
    if (users.isEmpty && enableBypass) {
      return RecognitionResult(
        status: 'ok',
        match: true,
        label: 'bypass',
        confidence: 0.5,
        assistance: false,
        message: 'Bypass activated - no local DB',
      );
    }
    String? bestLabel;
    double bestScore = 0.0;
    for (final u in users) {
      if (u.vector == null) continue;
      final sim = _cosineSimilarity(vector, u.vector!);
      if (sim > bestScore) {
        bestScore = sim;
        bestLabel = u.name;
      }
    }
    if (bestScore >= threshold && bestLabel != null) {
      return RecognitionResult(
        status: 'ok',
        match: true,
        label: bestLabel,
        confidence: bestScore,
        assistance: false,
        message: 'Matched locally',
      );
    }

    // 2) Si no hay match local, consultar API
    final apiResult = await ApiClient.instance.sendVector(vector, deviceId: deviceId, token: token);

    // Si la API falla y no hay base local, aplicar bypass si está activado
    if (apiResult.status != 'ok' && users.isEmpty && enableBypass) {
      return RecognitionResult(
        status: 'ok',
        match: true,
        label: 'bypass',
        confidence: 0.5,
        assistance: false,
        message: 'Bypass activated - API unavailable and no local DB',
      );
    }

    // 3) Si la API devuelve match, guardar localmente para acelerar futuras detecciones
    if (apiResult.match && apiResult.label != null) {
      final newUser = UserModel(
        id: apiResult.label!,
        name: apiResult.label!,
        role: UserRole.alumno,
        vector: vector,
      );
      await LocalStorageService.instance.addOrUpdate(newUser);
    }

    return apiResult;
  }
}
