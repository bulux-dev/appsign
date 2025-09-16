import os, glob, time
import cv2
import numpy as np
import mediapipe as mp
from collections import deque, Counter

# ======= EDITA AQUÍ =======
DATA_DIR = "/Users/danielbulux/Desktop/senas/"  # carpeta con subcarpetas por clase
CAM_INDEX = 0
MAX_HANDS = 1
K_NEIGHBORS = 5
DIST_THRESHOLD = 0.35   # si la distancia media es mayor -> Unknown (ajústalo)
SMOOTH_WINDOW = 15      # suavizado temporal de predicción
DET_CONF = 0.6
# ==========================

mp_hands = mp.solutions.hands
mp_draw  = mp.solutions.drawing_utils
mp_style = mp.solutions.drawing_styles

VALID_EXTS = ("*.jpg","*.jpeg","*.png","*.bmp","*.webp")

def norm_landmarks(landmarks):
    a = np.array(landmarks, dtype=np.float32)  # (21,3) en [0..1]
    a -= a[0]                                  # trasladar muñeca al origen
    s = np.max(np.abs(a[:, :2])) + 1e-6
    a[:, :3] /= s
    return a.flatten()                         # (63,)

def load_dataset(root):
    X, y, labels = [], [], []
    classes = [d for d in os.listdir(root) if os.path.isdir(os.path.join(root,d))]
    classes.sort()
    print(f"Cargando clases: {classes}")
    with mp_hands.Hands(static_image_mode=True, max_num_hands=1,
                        model_complexity=1, min_detection_confidence=DET_CONF) as hands:
        for label in classes:
            folder = os.path.join(root, label)
            paths = []
            for e in VALID_EXTS:
                paths += glob.glob(os.path.join(folder, e))
            ok = 0
            for p in paths:
                img = cv2.imread(p)
                if img is None: continue
                res = hands.process(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
                if not res.multi_hand_landmarks: continue
                hls = res.multi_hand_landmarks[0]
                feats = norm_landmarks([(q.x,q.y,q.z) for q in hls.landmark])
                X.append(feats); y.append(label); ok += 1
            print(f"  {label}: {ok} muestras")
            if ok > 0: labels.append(label)
    X = np.array(X, dtype=np.float32)
    y = np.array(y)
    return X, y, labels

def knn_predict(x, X, y, k=5):
    if len(X) == 0:
        return "Unknown", 1e9
    # Distancia euclídea
    dists = np.linalg.norm(X - x, axis=1)  # (N,)
    idx = np.argsort(dists)[:k]
    top_labels = y[idx]
    top_dists  = dists[idx]
    vote = Counter(top_labels).most_common(1)[0][0]
    mean_dist = float(np.mean(top_dists))
    return vote, mean_dist

def main():
    # 1) Cargar dataset desde tus imágenes
    X, y, labels = load_dataset(DATA_DIR)
    if len(labels) == 0:
        raise SystemExit(f"No encontré clases válidas en {DATA_DIR}. Revisa la estructura de carpetas.")
    print(f"Total muestras: {len(X)}")

    # 2) Cámara en vivo + clasificación k-NN
    cap = cv2.VideoCapture(CAM_INDEX)
    if not cap.isOpened():
        raise SystemExit(f"No pude abrir la cámara {CAM_INDEX}")

    preds_window = deque(maxlen=SMOOTH_WINDOW)
    fps_hist = deque(maxlen=30)
    last_t = time.time()

    with mp_hands.Hands(static_image_mode=False, max_num_hands=MAX_HANDS,
                        model_complexity=1, min_detection_confidence=DET_CONF,
                        min_tracking_confidence=0.6) as hands:
        while True:
            ok, frame = cap.read()
            if not ok: break
            frame = cv2.flip(frame, 1)
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            res = hands.process(rgb)

            pred_text = "No hand"
            if res.multi_hand_landmarks:
                # usa la primera mano
                hls = res.multi_hand_landmarks[0]
                mp_draw.draw_landmarks(
                    frame, hls, mp_hands.HAND_CONNECTIONS,
                    mp_style.get_default_hand_landmarks_style(),
                    mp_style.get_default_hand_connections_style()
                )
                feats = norm_landmarks([(p.x,p.y,p.z) for p in hls.landmark]).reshape(1,-1)
                label, dist = knn_predict(feats[0], X, y, k=K_NEIGHBORS)
