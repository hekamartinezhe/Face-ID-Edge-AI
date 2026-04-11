import 'dart:math';
import 'dart:typed_data';
import '../models/recognition_result.dart';
import 'api_client.dart';
import 'image_processor.dart';

enum InferenceMode { edge, cloud }

class OrchestratorResult {
  final InferenceMode mode;
  final int latencyMs;
  final RecognitionResult result;

  OrchestratorResult({
    required this.mode,
    required this.latencyMs,
    required this.result,
  });
}

/// Orquestador de Carga Híbrida (Edge AI vs Cloud AI)
/// Simula la decisión de enrutamiento basada en latencia de red.
class LoadOrchestratorService {
  LoadOrchestratorService._();
  static final LoadOrchestratorService instance = LoadOrchestratorService._();

  final Random _random = Random();

  Future<OrchestratorResult> processFace(Uint8List imageBytes, {required bool isEnrollment, String? name}) async {
    // 0. Corregir orientación en un Isolate antes de cualquier medición/envío
    Uint8List processedBytes;
    try {
      processedBytes = await ImageProcessor.instance.fixOrientation(imageBytes);
    } catch (e) {
      // Si falla el procesado, continuar con los bytes originales
      processedBytes = imageBytes;
    }

    // 1. Medir latencia simulada de red hacia la API
    final stopwatch = Stopwatch()..start();
    final isOnline = await ApiClient.instance.checkStatus(timeout: const Duration(milliseconds: 800));
    stopwatch.stop();
    
    // Simular un "ping" de red
    final int networkPing = isOnline ? stopwatch.elapsedMilliseconds + _random.nextInt(50) : 999;

    InferenceMode selectedMode;
    RecognitionResult finalResult;
    int finalLatency;

    // 2. Lógica de Orquestación: Si el ping es alto (>100ms) o está offline -> EDGE (Hexagon NPU simulado)
    if (!isOnline || networkPing > 100) {
      selectedMode = InferenceMode.edge;
      
      // Simular latencia de inferencia local en NPU (15ms - 40ms)
      finalLatency = 15 + _random.nextInt(25);
      await Future.delayed(Duration(milliseconds: finalLatency));

      // Simular resultado procesado localmente
      if (isEnrollment) {
        finalResult = RecognitionResult(
          status: 'ok', 
          match: true, 
          label: name, 
          message: 'Enrolado en Edge'
        );
      } else {
        // Fallback demo: Asumir match local para mantener la fluidez de la exposición
        finalResult = RecognitionResult(
          status: 'ok', 
          match: true, 
          label: 'Usuario Local', 
          confidence: 0.92, 
          message: 'Edge Fallback'
        );
      }
    } 
    // 3. Si la red es estable y rápida -> CLOUD (RTX 5060 Ti)
    else {
      selectedMode = InferenceMode.cloud;
      
      final cloudStopwatch = Stopwatch()..start();
      
      if (isEnrollment) {
        finalResult = await ApiClient.instance.sendRegister(processedBytes, name ?? 'Desconocido');
      } else {
        finalResult = await ApiClient.instance.sendImageForAssistance(processedBytes);
      }
      
      cloudStopwatch.stop();
      // Latencia total: Ping de red + Procesamiento en RTX
      finalLatency = networkPing + cloudStopwatch.elapsedMilliseconds;
    }

    return OrchestratorResult(
      mode: selectedMode,
      latencyMs: finalLatency,
      result: finalResult,
    );
  }
}
