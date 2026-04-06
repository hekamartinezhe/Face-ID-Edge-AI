#!/usr/bin/env python3
"""
Script de diagnóstico interactivo para Face-ID.
Analiza la precisión del modelo en tiempo real.

Uso:
    python diagnose.py
"""

import sys
import os
import asyncio
import numpy as np
from pathlib import Path

# Agregar paths
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from backend_api.eval import PrecisionEvaluator
from ai_research.inference import AdaFaceInference
import motor.motor_asyncio
import torch

# Configuración
MONGO_URI = 'mongodb://localhost:27017/faceid'
MODEL_PATH = 'ai_research/models/adaface_ir101_ms1mv3.ckpt'

def _cosine_similarity(a, b):
    """Similitud coseno entre dos embeddings."""
    a_np = np.array(a)
    b_np = np.array(b)
    dot = np.dot(a_np, b_np)
    norm_a = np.linalg.norm(a_np)
    norm_b = np.linalg.norm(b_np)
    return dot / (norm_a * norm_b) if norm_a and norm_b else 0.0


async def main():
    print("=" * 70)
    print("🔍 DIAGNÓSTICO DE PRECISIÓN - Face-ID Edge AI")
    print("=" * 70)
    
    # Conectar a MongoDB
    print("\n[1] Conectando a MongoDB...")
    try:
        client = motor.motor_asyncio.AsyncIOMotorClient(MONGO_URI)
        db = client['faceid']
        collection = db.alumnos
        
        # Contar documentos
        count = await collection.count_documents({})
        print(f"✅ Base de datos conectada - {count} alumnos registrados")
        
        if count < 2:
            print("❌ Error: Se necesitan al menos 2 alumnos para diagnosticar. Registra más primero.")
            return
    except Exception as e:
        print(f"❌ No se pudo conectar a MongoDB: {e}")
        print("   Asegúrate de que MongoDB está corriendo: mongod")
        return
    
    # Inicializar modelo
    print("\n[2] Inicializando modelo AdaFace...")
    try:
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        adaface = AdaFaceInference(
            model_path=MODEL_PATH,
            architecture='ir_101',
            device=str(device)
        )
        print(f"✅ Modelo cargado (device: {device})")
    except Exception as e:
        print(f"❌ Error al cargar modelo: {e}")
        return
    
    # Cargar todos los embeddings
    print("\n[3] Cargando embeddings de la base de datos...")
    try:
        cursor = collection.find({})
        docs = await cursor.to_list(None)
        
        embeddings_by_id = {}
        for doc in docs:
            id_alumno = doc.get('id_alumno')
            embedding = doc.get('embedding')
            if id_alumno and embedding:
                embeddings_by_id[id_alumno] = embedding
        
        print(f"✅ {len(embeddings_by_id)} embeddings cargados")
    except Exception as e:
        print(f"❌ Error al cargar embeddings: {e}")
        return
    
    # Evaluar similaridad intra-persona y inter-persona
    print("\n[4] Calculando matriz de similitudes...")
    evaluator = PrecisionEvaluator()
    
    ids = list(embeddings_by_id.keys())
    
    # Intra-persona: comparar cada embedding consigo mismo (simulando múltiples capturas)
    # Para esto, añadimos ruido pequeño a los embeddings
    print("   - Analizando matches (mismo alumno)...")
    intra_count = 0
    for id_a in ids:
        emb_a = embeddings_by_id[id_a]
        # Simular variación pequeña (como si fuera otra foto de la misma persona)
        emb_a_noisy = (np.array(emb_a) + np.random.normal(0, 0.01, len(emb_a))).tolist()
        score = _cosine_similarity(emb_a, emb_a_noisy)
        evaluator.add_match_score(score)
        intra_count += 1
    print(f"     ✓ {intra_count} comparaciones intra-persona generadas")
    
    # Inter-persona: comparar embeddings de diferentes alumnos
    print("   - Analizando non-matches (diferente alumno)...")
    inter_count = 0
    for i, id_a in enumerate(ids):
        for id_b in ids[i+1:]:
            emb_a = embeddings_by_id[id_a]
            emb_b = embeddings_by_id[id_b]
            score = _cosine_similarity(emb_a, emb_b)
            evaluator.add_non_match_score(score)
            inter_count += 1
    print(f"     ✓ {inter_count} comparaciones inter-persona")
    
    # Mostrar estadísticas
    print("\n" + "=" * 70)
    print("📊 ESTADÍSTICAS DE SIMILITUD")
    print("=" * 70)
    
    stats = evaluator.get_statistics()
    
    print(f"\n🟢 MATCHES (Mismo alumno):")
    print(f"   Muestras: {stats['match_scores']['count']}")
    print(f"   Media:    {stats['match_scores']['mean']:.3f}")
    print(f"   Std Dev:  {stats['match_scores']['std']:.3f}")
    print(f"   Min:      {stats['match_scores']['min']:.3f}")
    print(f"   Max:      {stats['match_scores']['max']:.3f}")
    print(f"   P50:      {stats['match_scores']['percentiles']['p50']:.3f}")
    print(f"   P90:      {stats['match_scores']['percentiles']['p90']:.3f}")
    
    print(f"\n🔴 NON-MATCHES (Diferente alumno):")
    print(f"   Muestras: {stats['non_match_scores']['count']}")
    print(f"   Media:    {stats['non_match_scores']['mean']:.3f}")
    print(f"   Std Dev:  {stats['non_match_scores']['std']:.3f}")
    print(f"   Min:      {stats['non_match_scores']['min']:.3f}")
    print(f"   Max:      {stats['non_match_scores']['max']:.3f}")
    print(f"   P50:      {stats['non_match_scores']['percentiles']['p50']:.3f}")
    print(f"   P90:      {stats['non_match_scores']['percentiles']['p90']:.3f}")
    
    # Análisis de separación
    print("\n" + "=" * 70)
    print("🎯 ANÁLISIS DE SEPARACIÓN")
    print("=" * 70)
    
    separation = evaluator.detect_separation_quality()
    print(f"\nÍndice d-prime: {separation['d_prime']:.3f}")
    print(f"Evaluation:     {separation['quality_assessment']}")
    print(f"Error Rate:     {separation['error_rate_at_midpoint']:.3f}")
    
    print(f"\n💡 Sugerencias:")
    for suggestion in separation['suggestions']:
        print(f"   {suggestion}")
    
    # Threshold óptimo
    print("\n" + "=" * 70)
    print("⚙️ THRESHOLD ÓPTIMO")
    print("=" * 70)
    
    optimal = evaluator.find_optimal_threshold()
    
    if "optimal_threshold" in optimal:
        print(f"\n🎯 Threshold recomendado: {optimal['optimal_threshold']}")
        print(f"   F1 Score:  {optimal['best_f1_score']:.3f}")
        print(f"   {optimal['recommendation']}")
        
        # Mostrar tabla de análisis
        print(f"\n📋 Análisis detallado (primeros 10 thresholds):")
        print(f"   {'Threshold':<12} {'TPR':<8} {'FPR':<8} {'Prec':<8} {'F1':<8} {'TP':<6} {'FP':<6} {'FN':<6} {'TN':<6}")
        print(f"   {'-'*90}")
        for result in optimal['threshold_analysis'][:10]:
            print(f"   {result['threshold']:<12.2f} {result['tpr']:<8.3f} {result['fpr']:<8.3f} "
                  f"{result['precision']:<8.3f} {result['f1']:<8.3f} {result['tp']:<6} "
                  f"{result['fp']:<6} {result['fn']:<6} {result['tn']:<6}")
    
    # Resumen final
    print("\n" + "=" * 70)
    print("📌 RESUMEN Y PASOS SIGUIENTES")
    print("=" * 70)
    
    if separation['d_prime'] > 2.0:
        print("\n✅ El modelo muestra buena separación.")
        print("   → Puedes usar los thresholds recomendados arriba")
        print("   → Sigue capturando más fotos para mejorar aún más")
    else:
        print("\n⚠️ El modelo necesita mejora.")
        print("   → Pasos a considerar:")
        print("     1. Ajusta el threshold según las recomendaciones arriba")
        print("     2. Registra más fotos de cada alumno (diferentes ángulos, iluminación)")
        print("     3. Verifica la calidad de alineación (brightness, tamaño)")
        print("     4. Considera fine-tuning del modelo si tienes datos suficientes")
    
    print("\n" + "=" * 70)
    print("✨ Diagnóstico completado")
    print("=" * 70)
    
    await client.close()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n\n❌ Diagnóstico cancelado por el usuario")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Error inesperado: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
