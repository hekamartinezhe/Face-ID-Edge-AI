"""
Módulo de evaluación y diagnóstico de precisión del modelo Face-ID.
Herramienta para analizar scores de similitud y optimizar thresholds.
"""

import numpy as np
from typing import List, Tuple, Dict
import json


class PrecisionEvaluator:
    """Evalúa precisión del modelo basándose en scores de similitud."""
    
    def __init__(self):
        self.all_scores = []  # Todos los scores de similitud
        self.match_scores = []  # Scores de matches correctos (intra-persona)
        self.non_match_scores = []  # Scores de no-matches (inter-persona)
    
    def add_match_score(self, score: float):
        """Agrega un score de match correcto (dos rostros de la misma persona)."""
        self.match_scores.append(score)
        self.all_scores.append(score)
    
    def add_non_match_score(self, score: float):
        """Agrega un score de no-match (dos rostros de diferente persona)."""
        self.non_match_scores.append(score)
        self.all_scores.append(score)
    
    def get_statistics(self) -> Dict:
        """Retorna estadísticas de los scores."""
        if not self.all_scores:
            return {"error": "No scores available"}
        
        return {
            "total_scores": len(self.all_scores),
            "match_scores": {
                "count": len(self.match_scores),
                "mean": float(np.mean(self.match_scores)) if self.match_scores else 0.0,
                "std": float(np.std(self.match_scores)) if self.match_scores else 0.0,
                "min": float(np.min(self.match_scores)) if self.match_scores else 0.0,
                "max": float(np.max(self.match_scores)) if self.match_scores else 0.0,
                "percentiles": {
                    "p50": float(np.percentile(self.match_scores, 50)) if self.match_scores else 0.0,
                    "p90": float(np.percentile(self.match_scores, 90)) if self.match_scores else 0.0,
                    "p99": float(np.percentile(self.match_scores, 99)) if self.match_scores else 0.0,
                }
            },
            "non_match_scores": {
                "count": len(self.non_match_scores),
                "mean": float(np.mean(self.non_match_scores)) if self.non_match_scores else 0.0,
                "std": float(np.std(self.non_match_scores)) if self.non_match_scores else 0.0,
                "min": float(np.min(self.non_match_scores)) if self.non_match_scores else 0.0,
                "max": float(np.max(self.non_match_scores)) if self.non_match_scores else 0.0,
                "percentiles": {
                    "p50": float(np.percentile(self.non_match_scores, 50)) if self.non_match_scores else 0.0,
                    "p90": float(np.percentile(self.non_match_scores, 90)) if self.non_match_scores else 0.0,
                    "p99": float(np.percentile(self.non_match_scores, 99)) if self.non_match_scores else 0.0,
                }
            }
        }
    
    def find_optimal_threshold(self) -> Dict:
        """
        Encuentra el threshold óptimo basándose en la separación entre 
        matches y non-matches.
        
        Retorna threshold que maximiza: True Positive Rate - False Positive Rate
        """
        if not self.match_scores or not self.non_match_scores:
            return {"error": "Se necesitan tanto matches como non-matches para evaluar"}
        
        # Probar thresholds de 0.5 a 0.95
        thresholds = np.arange(0.50, 0.96, 0.01)
        best_threshold = 0.80
        best_f1 = 0.0
        
        results = []
        
        for threshold in thresholds:
            # True Positives: matches por encima del threshold
            tp = np.sum(np.array(self.match_scores) >= threshold)
            fp = np.sum(np.array(self.non_match_scores) >= threshold)
            fn = np.sum(np.array(self.match_scores) < threshold)
            tn = np.sum(np.array(self.non_match_scores) < threshold)
            
            # Métricas
            tpr = tp / (tp + fn) if (tp + fn) > 0 else 0.0  # Recall
            fpr = fp / (fp + tn) if (fp + tn) > 0 else 0.0
            precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
            f1 = 2 * (precision * tpr) / (precision + tpr) if (precision + tpr) > 0 else 0.0
            
            results.append({
                "threshold": round(float(threshold), 2),
                "tpr": round(tpr, 3),
                "fpr": round(fpr, 3),
                "precision": round(precision, 3),
                "f1": round(f1, 3),
                "tp": int(tp),
                "fp": int(fp),
                "fn": int(fn),
                "tn": int(tn)
            })
            
            if f1 > best_f1:
                best_f1 = f1
                best_threshold = float(threshold)
        
        return {
            "optimal_threshold": round(best_threshold, 2),
            "best_f1_score": round(best_f1, 3),
            "threshold_analysis": results,
            "recommendation": f"Usa threshold = {round(best_threshold, 2)} para máxima precisión (F1={round(best_f1, 3)})"
        }
    
    def detect_separation_quality(self) -> Dict:
        """
        Analiza qué tan bien separated están los match scores de los non-match scores.
        Si hay mucha superposición, el modelo tiene problemas.
        """
        if not self.match_scores or not self.non_match_scores:
            return {"error": "Se necesitan datos"}
        
        match_mean = np.mean(self.match_scores)
        non_match_mean = np.mean(self.non_match_scores)
        match_std = np.std(self.match_scores)
        non_match_std = np.std(self.non_match_scores)
        
        # Índice de separación: d-prime (discriminability)
        d_prime = (match_mean - non_match_mean) / np.sqrt((match_std**2 + non_match_std**2) / 2)
        
        # Porcentaje de superposición
        overlap_threshold = (match_mean + non_match_mean) / 2
        match_wrong = np.sum(np.array(self.match_scores) < overlap_threshold)
        non_match_wrong = np.sum(np.array(self.non_match_scores) >= overlap_threshold)
        error_rate = (match_wrong + non_match_wrong) / (len(self.match_scores) + len(self.non_match_scores))
        
        return {
            "match_mean": round(match_mean, 3),
            "match_std": round(match_std, 3),
            "non_match_mean": round(non_match_mean, 3),
            "non_match_std": round(non_match_std, 3),
            "d_prime": round(d_prime, 3),  # Entre más alto, mejor separación
            "error_rate_at_midpoint": round(error_rate, 3),
            "quality_assessment": self._assess_quality(d_prime),
            "suggestions": self._get_suggestions(error_rate, d_prime)
        }
    
    def _assess_quality(self, d_prime: float) -> str:
        """Evalúa la calidad de separación basada en d_prime."""
        if d_prime < 1.0:
            return "POBRE - Mucha superposición entre matches y non-matches"
        elif d_prime < 2.0:
            return "ACEPTABLE - Hay separación pero con errores"
        elif d_prime < 3.0:
            return "BUENO - Buena separación"
        else:
            return "EXCELENTE - Separación muy clara"
    
    def _get_suggestions(self, error_rate: float, d_prime: float) -> List[str]:
        """Retorna sugerencias de mejora."""
        suggestions = []
        
        if error_rate > 0.1:
            suggestions.append("❌ Error rate alto. Considera mejorar la alineación de rostros")
            suggestions.append("❌ Agrega más imágenes de entrenamiento con diferentes ángulos/iluminación")
        
        if d_prime < 2.0:
            suggestions.append("⚠️ Baja separación. Verifica que los embeddings estén normalizados correctamente")
            suggestions.append("⚠️ Considera usar un modelo más potente o mejor entrenado")
        
        if not suggestions:
            suggestions.append("✅ Rendimiento bueno. La precisión del modelo es aceptable")
        
        return suggestions


# Ejemplo de uso:
if __name__ == "__main__":
    evaluator = PrecisionEvaluator()
    
    # Simular scores de matches (mismo rostro)
    evaluator.add_match_score(0.92)
    evaluator.add_match_score(0.88)
    evaluator.add_match_score(0.95)
    evaluator.add_match_score(0.89)
    evaluator.add_match_score(0.91)
    
    # Simular scores de non-matches (diferente rostro)
    evaluator.add_non_match_score(0.45)
    evaluator.add_non_match_score(0.52)
    evaluator.add_non_match_score(0.38)
    evaluator.add_non_match_score(0.61)
    evaluator.add_non_match_score(0.48)
    
    stats = evaluator.get_statistics()
    optimal = evaluator.find_optimal_threshold()
    quality = evaluator.detect_separation_quality()
    
    print(json.dumps({"stats": stats, "optimal": optimal, "quality": quality}, indent=2))
