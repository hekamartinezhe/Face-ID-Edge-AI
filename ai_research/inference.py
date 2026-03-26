import net
import torch
import os
import pickle
import tempfile
import cv2
import numpy as np
from face_alignment import align

class AdaFaceInference:
    def __init__(self, model_path, architecture='ir_101', device='cuda'):
        self.device = device
        self.model_path = model_path
        self.architecture = architecture
        self.db_path = "face_db.pkl"
        self.db = self.load_db()
        self.model = self.load_pretrained_model()
        
    def load_db(self):
        if os.path.exists(self.db_path):
            with open(self.db_path, 'rb') as f:
                return pickle.load(f)
        return {}

    def save_db(self):
        with open(self.db_path, 'wb') as f:
            pickle.dump(self.db, f)

    def load_pretrained_model(self):
        model = net.build_model(self.architecture)
        statedict = torch.load(self.model_path, map_location=self.device)['state_dict']
        model_statedict = {key[6:]:val for key, val in statedict.items() if key.startswith('model.')}
        model.load_state_dict(model_statedict)
        model.to(self.device)
        model.eval()
        return model

    def to_input(self, pil_rgb_image):
        np_img = np.array(pil_rgb_image)
        brg_img = ((np_img[:,:,::-1] / 255.) - 0.5) / 0.5
        tensor = torch.tensor([brg_img.transpose(2,0,1)]).float()
        return tensor.to(self.device)

    def _get_feature(self, frame):
        with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as tmp:
            temp_path = tmp.name
        
        cv2.imwrite(temp_path, frame)
        
        try:
            aligned_rgb_img = align.get_aligned_face(temp_path)
            if aligned_rgb_img is None:
                return None
            
            bgr_tensor_input = self.to_input(aligned_rgb_img)
            with torch.no_grad():
                feature, _ = self.model(bgr_tensor_input)
            return feature
        finally:
            os.remove(temp_path)

    def registrar_nuevo_usuario(self, frame, nombre):
        feature = self._get_feature(frame)
        if feature is None:
            return False, "No se detectó ningún rostro en la imagen proporcionada."
        
        self.db[nombre] = feature.cpu()
        self.save_db()
        return True, f"Usuario '{nombre}' registrado correctamente."

    def run_inference(self, frame):
        if not self.db:
            return "base_vacia", 0.0

        feature = self._get_feature(frame)
        if feature is None:
            raise Exception("No se detectó rostro para procesar la asistencia.")
        
        feature = feature.cpu()
        
        best_name = "desconocido"
        best_score = -1.0
        
        for name, saved_feature in self.db.items():
            score = (feature @ saved_feature.T).item()
            if score > best_score:
                best_score = score
                best_name = name
                
        return best_name, best_score
