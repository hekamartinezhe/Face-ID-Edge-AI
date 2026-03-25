class RecognitionResult {
  final String status;
  final bool match;
  final String? label;
  final double? confidence;
  final bool assistance;
  final String? message;

  RecognitionResult({
    required this.status,
    required this.match,
    this.label,
    this.confidence,
    this.assistance = false,
    this.message,
  });

  factory RecognitionResult.fromJson(Map<String, dynamic> json) => RecognitionResult(
        status: json['status'] as String? ?? 'error',
        match: json['match'] == true,
        label: json['label'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble(),
        assistance: json['assistance'] == true,
        message: json['message'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'status': status,
        'match': match,
        'label': label,
        'confidence': confidence,
        'assistance': assistance,
        'message': message,
      };
}
