import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math' as dart_math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_client.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceCameraScreen extends StatefulWidget {
  const FaceCameraScreen({super.key});

  @override
  State<FaceCameraScreen> createState() => _FaceCameraScreenState();
}

class _FaceCameraScreenState extends State<FaceCameraScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  bool _isProcessing = false;

  bool _isApiConnected = false;
  bool _isCheckingApi = true;

  final TextEditingController _nameController = TextEditingController();

  // Usamos `ApiClient.instance.baseUrl` en lugar de una URL hardcodeada

  // Detector principal (validación de calidad)
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableTracking: false,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  bool _isModelLoaded = false;

  List<double>? _lastEmbeddings;
  bool _showVectorPanel = false;
  late AnimationController _panelAnimController;
  late Animation<double> _panelAnimation;

  static const int _embeddingSize = 512;

  @override
  void initState() {
    super.initState();
    _panelAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _panelAnimation = CurvedAnimation(
      parent: _panelAnimController,
      curve: Curves.easeInOut,
    );
    _initCamera();
    _loadModel();
    _checkApiStatus();
  }

  // ── INIT MODELO (ML Kit — sin TFLite) ───────────────────
  Future<void> _loadModel() async {
    // ML Kit ya está disponible, no necesitamos TFLite
    setState(() => _isModelLoaded = true);
    debugPrint("✅ Extracción por landmarks + contornos ML Kit activa");
  }

  // ── CÁMARA ───────────────────────────────────────────────
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      _controller = CameraController(
        frontCam,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      _showSnack("Error al iniciar la cámara", isError: true);
    }
  }

  // ── API STATUS ───────────────────────────────────────────
  Future<void> _checkApiStatus() async {
    setState(() => _isCheckingApi = true);
    try {
      final ok = await ApiClient.instance.checkStatus();
      setState(() => _isApiConnected = ok);
      _showSnack(ok ? "✅ Conectado al servidor" : "❌ No se pudo conectar a la API",
          isError: !ok);
    } catch (e) {
      setState(() => _isApiConnected = false);
      _showSnack("❌ No se pudo conectar a la API", isError: true);
    } finally {
      if (mounted) setState(() => _isCheckingApi = false);
    }
  }

  // ── VALIDACIÓN DE CALIDAD CON ML KIT ────────────────────
  Future<bool> _validateFaceQuality(XFile imageFile) async {
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final List<Face> faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      _showSnack("❌ No se detectó ningún rostro. Centra tu cara.", isError: true);
      return false;
    }
    if (faces.length > 1) {
      _showSnack("❌ Hay más de una persona en cámara.", isError: true);
      return false;
    }

    final face = faces.first;

    if ((face.headEulerAngleY ?? 0).abs() > 15) {
      _showSnack("⚠️ Mira directamente a la cámara.", isError: true);
      return false;
    }

    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;
    if (leftEye == null || rightEye == null || leftEye < 0.6 || rightEye < 0.6) {
      _showSnack("👓 Ojos no visibles. Quítate los lentes.", isError: true);
      return false;
    }

    return true;
  }

  // ── EXTRACCIÓN DE VECTOR 512D CON ML KIT ────────────────
  Future<List<double>> _extractEmbeddings(XFile imageFile) async {
    final inputImage = InputImage.fromFilePath(imageFile.path);

    // Detector con landmarks Y contornos activados
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableClassification: true,
        enableContours: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );

    final List<Face> faces = await detector.processImage(inputImage);
    await detector.close();

    if (faces.isEmpty) {
      throw Exception("No se detectó rostro para extraer vector");
    }

    final face = faces.first;
    final List<double> rawVector = [];

    // ── 1. BOUNDING BOX normalizado (4 valores) ────────────
    final box = face.boundingBox;
    rawVector.addAll([
      box.left / 1000.0,
      box.top / 1000.0,
      box.width / 1000.0,
      box.height / 1000.0,
    ]);

    // ── 2. ÁNGULOS DE LA CABEZA (3 valores) ────────────────
    rawVector.addAll([
      (face.headEulerAngleX ?? 0.0) / 90.0,
      (face.headEulerAngleY ?? 0.0) / 90.0,
      (face.headEulerAngleZ ?? 0.0) / 90.0,
    ]);

    // ── 3. CLASIFICACIONES (2 valores) ─────────────────────
    rawVector.addAll([
      face.leftEyeOpenProbability ?? 0.0,
      face.rightEyeOpenProbability ?? 0.0,
    ]);

    // ── 4. LANDMARKS — puntos clave del rostro ─────────────
    const landmarkTypes = [
      FaceLandmarkType.leftEye,
      FaceLandmarkType.rightEye,
      FaceLandmarkType.noseBase,
      FaceLandmarkType.leftEar,
      FaceLandmarkType.rightEar,
      FaceLandmarkType.leftCheek,
      FaceLandmarkType.rightCheek,
      FaceLandmarkType.leftMouth,
      FaceLandmarkType.rightMouth,
      FaceLandmarkType.bottomMouth,
    ];

    for (final type in landmarkTypes) {
      final landmark = face.landmarks[type];
      if (landmark != null) {
        rawVector.add(landmark.position.x / 1000.0);
        rawVector.add(landmark.position.y / 1000.0);
      } else {
        rawVector.add(0.0);
        rawVector.add(0.0);
      }
    }

    // ── 5. CONTORNOS — geometría detallada del rostro ───────
    const contourTypes = [
      FaceContourType.face,
      FaceContourType.leftEye,
      FaceContourType.rightEye,
      FaceContourType.noseBridge,
      FaceContourType.leftEyebrowTop,
      FaceContourType.leftEyebrowBottom,
      FaceContourType.rightEyebrowTop,
      FaceContourType.rightEyebrowBottom,
      FaceContourType.upperLipTop,
      FaceContourType.upperLipBottom,
      FaceContourType.lowerLipTop,
      FaceContourType.lowerLipBottom,
    ];

    for (final type in contourTypes) {
      final contour = face.contours[type];
      if (contour != null) {
        for (final point in contour.points) {
          rawVector.add(point.x / 1000.0);
          rawVector.add(point.y / 1000.0);
          if (rawVector.length >= 490) break;
        }
      }
      if (rawVector.length >= 490) break;
    }

    // ── 6. PADDING hasta exactamente 512 dimensiones ────────
    while (rawVector.length < _embeddingSize) {
      final i = rawVector.length;
      final prev = rawVector[i - 1];
      final prev2 = rawVector[i - 2];
      rawVector.add((prev - prev2).abs() * 0.5);
    }

    // Recortar si se pasó de 512
    final trimmed = rawVector.sublist(0, _embeddingSize);

    // ── 7. L2 NORMALIZATION ──────────────────────────────────
    final normalized = _l2Normalize(trimmed);

    debugPrint("✅ Vector extraído: ${normalized.length}d");
    debugPrint("   Raw antes de trim: ${rawVector.length}");
    debugPrint("   [0..4]:     ${normalized.sublist(0, 5)}");
    debugPrint("   [507..511]: ${normalized.sublist(507)}");

    return normalized;
  }

  // ── L2 NORMALIZATION ─────────────────────────────────────
  List<double> _l2Normalize(List<double> vector) {
    double norm = vector.fold(0.0, (sum, v) => sum + v * v);
    norm = norm > 0 ? dart_math.sqrt(norm) : 1.0;
    return vector.map((v) => v / norm).toList();
  }

  // ── REGISTRO Y ASISTENCIA ────────────────────────────────
  Future<void> _registerUser() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnack("Escribe un nombre para registrar", isError: true);
      return;
    }
    await _processFaceAction("register");
  }

  Future<void> _checkAssistance() async {
    await _processFaceAction("asistence");
  }

  // ── PROCESAMIENTO PRINCIPAL ──────────────────────────────
  Future<void> _processFaceAction(String mode) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // 1. Tomar foto
      final image = await _controller!.takePicture();

      // 2. Validar calidad
      final isFaceValid = await _validateFaceQuality(image);
      if (!isFaceValid) {
        setState(() => _isProcessing = false);
        return;
      }

      // 3. Extraer vector (solo para mostrar en panel de debug)
      final embeddings = await _extractEmbeddings(image);

      // 4. Guardar y mostrar panel
      setState(() => _lastEmbeddings = embeddings);
      _toggleVectorPanel(forceOpen: true);

      // 5. Enviar imagen al servidor usando ApiClient (multipart)
      final bytes = await image.readAsBytes();

      if (mode == "register") {
        final nombre = _nameController.text.trim();
        final res = await ApiClient.instance.sendRegister(bytes, nombre, filename: image.name);
        if (res.status == 'error') {
          _showSnack('❌ Registro fallido: ${res.message}', isError: true);
        } else {
          _showSnack('✅ Registrado: ${res.message ?? nombre}');
          _nameController.clear();
        }
      } else {
        final res = await ApiClient.instance.sendImageForAssistance(bytes, filename: image.name);
        if (res.status == 'error') {
          _showSnack('❌ Error API: ${res.message}', isError: true);
        } else if (res.match) {
          final confPct = (res.confidence ?? 0.0) * 100.0;
          _showSnack('✅ Hola ${res.label} (${confPct.toStringAsFixed(1)}%)');
        } else {
          final confPct = (res.confidence ?? 0.0) * 100.0;
          _showSnack('🚫 Desconocido — confianza ${confPct.toStringAsFixed(1)}%', isError: true);
        }
      }
    } catch (e) {
      _showSnack("📡 Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _toggleVectorPanel({bool? forceOpen}) {
    setState(() => _showVectorPanel = forceOpen ?? !_showVectorPanel);
    if (_showVectorPanel) {
      _panelAnimController.forward();
    } else {
      _panelAnimController.reverse();
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── PANEL DE VECTORES (DEBUG) ────────────────────────────
  Widget _buildVectorPanel() {
    if (_lastEmbeddings == null) return const SizedBox.shrink();

    final embeddings = _lastEmbeddings!;
    final double minVal = embeddings.reduce((a, b) => a < b ? a : b);
    final double maxVal = embeddings.reduce((a, b) => a > b ? a : b);
    final double mean = embeddings.reduce((a, b) => a + b) / embeddings.length;
    final double variance = embeddings
            .map((v) => (v - mean) * (v - mean))
            .reduce((a, b) => a + b) /
        embeddings.length;
    final double stdDev = dart_math.sqrt(variance);

    return SizeTransition(
      sizeFactor: _panelAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withOpacity(0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.data_array, color: Colors.cyanAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "EMBEDDING — ${embeddings.length} dims",
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.greenAccent, width: 0.8),
                    ),
                    child: const Text(
                      "ML Kit",
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Stats
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statChip("MIN", minVal.toStringAsFixed(4), Colors.redAccent),
                  _statChip("MAX", maxVal.toStringAsFixed(4), Colors.greenAccent),
                  _statChip("MEDIA", mean.toStringAsFixed(4), Colors.yellowAccent),
                  _statChip("STD", stdDev.toStringAsFixed(4), Colors.purpleAccent),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // Heatmap primeros 64 valores
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Primeros 64 valores (toca cada celda para ver el valor exacto):",
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: List.generate(64, (i) {
                      final val = embeddings[i];
                      final intensity = ((val + 1.0) / 2.0).clamp(0.0, 1.0);
                      final color = Color.lerp(
                        Colors.blue.shade900,
                        Colors.cyanAccent,
                        intensity,
                      )!;
                      return Tooltip(
                        message: "[$i]: ${val.toStringAsFixed(6)}",
                        child: Container(
                          width: 36,
                          height: 20,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            val.toStringAsFixed(2),
                            style: TextStyle(
                              color: intensity > 0.5 ? Colors.black : Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "... ${embeddings.length - 64} valores más (total: ${embeddings.length})",
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  const SizedBox(height: 10),
                  // Botón imprimir vector completo
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.cyanAccent,
                        side: BorderSide(
                            color: Colors.cyanAccent.withOpacity(0.5)),
                      ),
                      onPressed: () {
                        debugPrint(
                            "📋 Vector completo 512d:\n${jsonEncode(embeddings)}");
                        _showSnack(
                            "✅ Vector impreso en consola (flutter logs)");
                      },
                      icon: const Icon(Icons.terminal, size: 14),
                      label: const Text(
                        "Imprimir vector completo en consola",
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 9,
              letterSpacing: 0.8),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ── BUILD ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: CircularProgressIndicator(color: Colors.cyanAccent)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Face-ID System"),
        backgroundColor: Colors.transparent,
        actions: [
          // Toggle panel vectores
          if (_lastEmbeddings != null)
            IconButton(
              icon: Icon(
                _showVectorPanel ? Icons.visibility_off : Icons.data_array,
                color: Colors.cyanAccent,
              ),
              onPressed: _toggleVectorPanel,
              tooltip: "Toggle vectores",
            ),
          // Badge ML Kit
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.greenAccent, width: 0.8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.memory, color: Colors.greenAccent, size: 12),
                  SizedBox(width: 4),
                  Text(
                    "ML Kit ✓",
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Icono conexión API
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: _isCheckingApi
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : IconButton(
                    icon: Icon(
                      _isApiConnected ? Icons.wifi : Icons.wifi_off,
                      color: _isApiConnected
                          ? Colors.greenAccent
                          : Colors.redAccent,
                    ),
                    onPressed: _checkApiStatus,
                    tooltip: "Verificar conexión",
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Cámara
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CameraPreview(_controller!),
                  // Óvalo guía
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isProcessing
                            ? Colors.yellow
                            : Colors.cyanAccent,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(200),
                    ),
                    width: 220,
                    height: 300,
                  ),
                  // Overlay procesando
                  if (_isProcessing)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                                color: Colors.cyanAccent),
                            SizedBox(height: 16),
                            Text(
                              "Procesando...",
                              style: TextStyle(
                                  color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Panel de vectores (animado)
            _buildVectorPanel(),

            // Controles
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    enabled: !_isProcessing && _isApiConnected,
                    decoration: InputDecoration(
                      hintText: "Nombre para registro",
                      hintStyle: const TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Colors.cyanAccent.withOpacity(0.5)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.cyanAccent),
                      ),
                      disabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[900],
                        ),
                        onPressed:
                            (_isProcessing || !_isApiConnected)
                                ? null
                                : _checkAssistance,
                        icon: const Icon(Icons.login),
                        label: const Text("ASISTENCIA"),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.grey[800],
                        ),
                        onPressed:
                            (_isProcessing || !_isApiConnected)
                                ? null
                                : _registerUser,
                        icon: const Icon(Icons.person_add),
                        label: const Text("REGISTRAR"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _faceDetector.close();
    _controller?.dispose();
    _nameController.dispose();
    _panelAnimController.dispose();
    super.dispose();
  }
}