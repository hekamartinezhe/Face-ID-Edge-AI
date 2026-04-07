import sys
import os
import torch

from . import mtcnn
import argparse
from PIL import Image
from tqdm import tqdm
import random
from datetime import datetime

# Detectar GPU con fallback a CPU
device = 'cuda:0' if torch.cuda.is_available() else 'cpu'
print(f"[MTCNN] Using device: {device}")
mtcnn_model = mtcnn.MTCNN(device=device, crop_size=(112, 112))

def add_padding(pil_img, top, right, bottom, left, color=(0,0,0)):
    width, height = pil_img.size
    new_width = width + right + left
    new_height = height + top + bottom
    result = Image.new(pil_img.mode, (new_width, new_height), color)
    result.paste(pil_img, (left, top))
    return result

def validate_face_quality(face_pil, bbox=None, min_confidence=0.5):
    """
    Valida la calidad y tamaño del rostro detectado.
    Returns: (is_valid, quality_score)
    """
    if face_pil is None:
        return False, 0.0
    
    # Validar dimensiones (debe ser 112x112 después del alignment)
    if face_pil.size != (112, 112):
        return False, 0.0
    
    # Validar que la imagen no sea muy oscura/clara (histograma)
    import numpy as np
    face_array = np.array(face_pil)
    brightness = np.mean(face_array) / 255.0
    
    # Brightness debe estar entre 0.2 y 0.8 para buena calidad
    if brightness < 0.2 or brightness > 0.8:
        quality_score = max(0.0, 1.0 - abs(brightness - 0.5) * 2)
    else:
        quality_score = 1.0
    
    # Si el bbox existe, validar que sea de tamaño razonable
    if bbox is not None and len(bbox) >= 4:
        face_w = bbox[2] - bbox[0]
        face_h = bbox[3] - bbox[1]
        face_area = face_w * face_h
        if face_area < 50 * 50:  # Rostro muy pequeño
            quality_score *= 0.5
    
    is_valid = quality_score >= min_confidence
    return is_valid, quality_score

def get_aligned_face(image_path, rgb_pil_image=None):
    """
    Detecta y alinea rostro. Retorna tupla (face_pil, quality_score, bbox)
    """
    if rgb_pil_image is None:
        img = Image.open(image_path).convert('RGB')
    else:
        assert isinstance(rgb_pil_image, Image.Image), 'Face alignment module requires PIL image or path to the image'
        img = rgb_pil_image
    
    # Validar que la imagen tenga dimensiones válidas
    if img.size[0] < 50 or img.size[1] < 50:
        print('[ALIGN] Face detection Failed: Image too small')
        return None, 0.0, None
    
    # find face
    try:
        bboxes, faces = mtcnn_model.align_multi(img, limit=1)
        if not faces or len(faces) == 0:
            print('[ALIGN] Face detection: No face detected')
            return None, 0.0, None
        
        face = faces[0]
        bbox = bboxes[0] if len(bboxes) > 0 else None
        
        # Validar calidad del rostro detectado
        is_valid, quality_score = validate_face_quality(face, bbox, min_confidence=0.4)
        
        if not is_valid:
            print(f'[ALIGN] Face quality too low: {quality_score:.2f}')
            return face, quality_score, bbox  # Retorna igualmente pero marca baja calidad
        
        print(f'[ALIGN] Face detected with quality: {quality_score:.2f}')
        return face, quality_score, bbox
        
    except IndexError as e:
        print('[ALIGN] Face detection Failed due to IndexError.')
        print(f'IndexError: {e}')
        return None, 0.0, None
    except Exception as e:
        print('[ALIGN] Face detection Failed due to error.')
        print(f'Exception: {type(e).__name__}: {e}')
        return None, 0.0, None


