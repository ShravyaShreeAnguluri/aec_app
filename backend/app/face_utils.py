import os
import numpy as np
import cv2
from insightface.app import FaceAnalysis

# -------------------------------------------------
# 🔥 IMPORTANT: Prevent heavy downloads in memory
# -------------------------------------------------
os.environ["INSIGHTFACE_HOME"] = "/tmp/.insightface"

# -------------------------------------------------
# 🔥 Lazy Load Model (VERY IMPORTANT)
# -------------------------------------------------
face_app = None

def get_face_app():
    global face_app

    if face_app is None:
        face_app = FaceAnalysis(
            name="buffalo_sc",  # 🔥 lighter model (important)
            providers=["CPUExecutionProvider"]
        )

        face_app.prepare(
            ctx_id=0,
            det_size=(320, 320),  # 🔥 reduced memory
            det_thresh=0.5
        )

    return face_app


# -------------------------------------------------
# Extract Face Embedding
# -------------------------------------------------
def extract_face_embedding(image_bytes: bytes):

    image_array = np.frombuffer(image_bytes, np.uint8)
    image = cv2.imdecode(image_array, cv2.IMREAD_COLOR)

    if image is None:
        return None

    # Improve lighting slightly
    image = cv2.convertScaleAbs(image, alpha=1.2, beta=10)

    # 🔥 Load model only when needed
    app = get_face_app()

    faces = app.get(image)

    if not faces:
        return None

    # Largest face
    largest_face = max(
        faces,
        key=lambda x: (x.bbox[2] - x.bbox[0]) * (x.bbox[3] - x.bbox[1])
    )

    embedding = largest_face.embedding

    # Normalize
    norm = np.linalg.norm(embedding)
    if norm == 0:
        return None

    return embedding / norm


# -------------------------------------------------
# Compare Faces
# -------------------------------------------------
def compare_faces(embedding1, embedding2, threshold=0.6):

    if embedding1 is None or embedding2 is None:
        return False

    similarity = np.dot(embedding1, embedding2) / (
        np.linalg.norm(embedding1) * np.linalg.norm(embedding2)
    )

    return similarity > threshold
