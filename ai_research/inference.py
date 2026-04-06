import net
import torch
import os
from face_alignment import align
import numpy as np


adaface_models = {
    'ir_50':"pretrained/adaface_ir50_ms1mv2.ckpt",
}
class AdaFaceInference:
    """Wrapper to load AdaFace checkpoint safely and run simple inference.

    Usage:
        engine = AdaFaceInference(model_path='models/adaface_ir101_ms1mv3.ckpt', architecture='ir_101', device='cpu')
        name, score = engine.run_inference(frame_numpy_bgr)
    """
    def __init__(self, model_path: str, architecture: str = 'ir_50', device: str = 'cpu'):
        self.device = torch.device(device if device in ['cpu','cuda'] else device)
        # resolve model_path relative to this file when not absolute
        if not os.path.isabs(model_path):
            base = os.path.dirname(os.path.abspath(__file__))
            candidate = os.path.join(base, model_path)
        else:
            candidate = model_path

        if architecture in adaface_models:
            # allow mapping via internal table if requested
            candidate = os.path.join(os.path.dirname(os.path.abspath(__file__)), adaface_models.get(architecture, candidate))

        if not os.path.exists(candidate):
            raise FileNotFoundError(f"AdaFace checkpoint not found: {candidate}")

        # load checkpoint
        ckpt = torch.load(candidate, map_location=self.device)
        if 'state_dict' in ckpt:
            statedict = ckpt['state_dict']
        else:
            statedict = ckpt

        model = net.build_model(architecture)
        model_statedict = {key[6:]: val for key, val in statedict.items() if key.startswith('model.')}
        model.load_state_dict(model_statedict)
        model.to(self.device)
        model.eval()
        self.model = model

    def to_input(self, pil_rgb_image):
        np_img = np.array(pil_rgb_image)
        brg_img = ((np_img[:, :, ::-1] / 255.0) - 0.5) / 0.5
        tensor = torch.tensor([brg_img.transpose(2, 0, 1)]).float().to(self.device)
        return tensor
    
    def normalize_embedding(self, embedding):
        """
        Normaliza embedding con L2 norm para mejor similitud coseno.
        embedding: lista de floats [512,]
        retorna: np.array normalizado
        """
        emb_array = np.array(embedding)
        norm = np.linalg.norm(emb_array)
        if norm > 0:
            return (emb_array / norm).tolist()
        return embedding

    def run_inference(self, frame_numpy_bgr):
        """
        Ejecuta inferencia completa: alineamiento → extracción de embedding → normalización
        Retorna: (embedding, quality_metric, alignment_quality)
        """
        try:
            # Guardar frame temporalmente para alineamiento
            import cv2
            tmp_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'tmp_infer.jpg')
            cv2.imwrite(tmp_path, frame_numpy_bgr)
            
            # Obtener rostro alineado y calidad
            aligned, alignment_quality, bbox = align.get_aligned_face(tmp_path)
            
            if aligned is None:
                print("[WARNING] Face alignment returned None - no face detected or alignment failed")
                return (None, 0.0, 0.0)
            
            # Convertir a tensor y extraer embedding
            input_tensor = self.to_input(aligned)
            with torch.no_grad():
                feat, norm = self.model(input_tensor)
            
            # Obtener vector en numpy
            vec_raw = feat.cpu().numpy().reshape(-1)
            norm_score = float(norm.cpu().numpy().reshape(-1)[0])
            
            # Normalizar embedding con L2 norm
            vec_normalized = self.normalize_embedding(vec_raw.tolist())
            
            print(f"[INFERENCE] Embedding extracted - alignment_quality: {alignment_quality:.2f}, norm_score: {norm_score:.2f}")
            
            # Retorna: (embedding_normalizado, norm_score_del_modelo, alignment_quality)
            return (vec_normalized, norm_score, alignment_quality)
            
        except Exception as e:
            print(f"[ERROR] Exception in run_inference: {e}")
            import traceback
            traceback.print_exc()
            return (None, 0.0, 0.0)

def to_input(pil_rgb_image):
    np_img = np.array(pil_rgb_image)
    brg_img = ((np_img[:,:,::-1] / 255.) - 0.5) / 0.5
    tensor = torch.tensor([brg_img.transpose(2,0,1)]).float()
    return tensor


if __name__ == '__main__':
    pass


