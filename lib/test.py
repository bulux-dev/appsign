import cv2
import time
import numpy as np
import mediapipe as mp

# Parámetros ajustables
CAM_INDEX = 0          # Si no abre, prueba 1 o 2
MAX_HANDS = 2          # 1 o 2 manos
DET_CONF = 0.6         # min_detection_confidence
TRK_CONF = 0.6         # min_tracking_confidence
MODEL_COMPLEXITY = 1   # 0=rápido, 1=equilibrado, 2=preciso

mp_hands = mp.solutions.hands
mp_drawing = mp.solutions.drawing_utils
mp_styles = mp.solutions.drawing_styles

def main():
    cap = cv2.VideoCapture(CAM_INDEX)
    if not cap.isOpened():
        print(f"No se pudo abrir la cámara en el índice {CAM_INDEX}. "
              f"Prueba cambiar CAM_INDEX a 1 o 2.")
        return

    # Para FPS
    last_t = time.time()
    fps_hist = []

    # Configurar MediaPipe Hands
    with mp_hands.Hands(
        static_image_mode=False,
        max_num_hands=MAX_HANDS,
        model_complexity=MODEL_COMPLEXITY,
        min_detection_confidence=DET_CONF,
        min_tracking_confidence=TRK_CONF
    ) as hands:

        while True:
            ok, frame = cap.read()
            if not ok:
                print("No se pudo leer frame de la cámara.")
                break

            # Flip horizontal para que actúe como espejo
            frame = cv2.flip(frame, 1)

            # MediaPipe usa RGB
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            result = hands.process(rgb)

            # Dibuja landmarks si hay manos
            if result.multi_hand_landmarks:
                for hand_landmarks, handedness in zip(
                    result.multi_hand_landmarks,
                    result.multi_handedness
                ):
                    # Dibuja conexiones y puntos
                    mp_drawing.draw_landmarks(
                        frame,
                        hand_landmarks,
                        mp_hands.HAND_CONNECTIONS,
                        mp_styles.get_default_hand_landmarks_style(),
                        mp_styles.get_default_hand_connections_style(),
                    )

                    # Etiqueta: Left/Right + score
                    label = handedness.classification[0].label  # 'Left' o 'Right'
                    score = handedness.classification[0].score
                    x = int(hand_landmarks.landmark[0].x * frame.shape[1])
                    y = int(hand_landmarks.landmark[0].y * frame.shape[0])
                    text = f"{label} ({score:.2f})"
                    cv2.putText(frame, text, (x + 10, y - 10),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0,0,0), 3, cv2.LINE_AA)
                    cv2.putText(frame, text, (x + 10, y - 10),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255,255,255), 1, cv2.LINE_AA)

            # Calcula FPS
            now = time.time()
            fps = 1.0 / max(now - last_t, 1e-6)
            last_t = now
            fps_hist.append(fps)
            if len(fps_hist) > 30:
                fps_hist.pop(0)
            fps_avg = np.mean(fps_hist) if fps_hist else 0.0

            # Overlay de estado
            cv2.rectangle(frame, (0, 0), (frame.shape[1], 32), (0, 0, 0), -1)
            status = f"Hands: {MAX_HANDS} | DetConf: {DET_CONF} | TrkConf: {TRK_CONF} | FPS: {fps_avg:.1f} | Q para salir"
            cv2.putText(frame, status, (10, 22), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255,255,255), 1, cv2.LINE_AA)

            cv2.imshow("MediaPipe Hands - Detección", frame)
            key = cv2.waitKey(1) & 0xFF
            if key in (ord('q'), ord('Q'), 27):  # Q o ESC para salir
                break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()
