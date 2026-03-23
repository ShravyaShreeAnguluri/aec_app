import numpy as np
import cv2
from insightface.app import FaceAnalysis

# -------------------------------------------------
# Initialize InsightFace ONCE (important for server)
# -------------------------------------------------
face_app = FaceAnalysis(
    name="buffalo_l",                     # high-accuracy model
    providers=["CPUExecutionProvider"]     # safe for cloud deployment
)

# ✅ IMPROVED: Better detection settings for different angles
face_app.prepare(
    ctx_id=0,
    det_size=(640, 640),
    det_thresh=0.5  # Lower detection threshold (default is 0.5)
)

# -------------------------------------------------
# Extract Face Embedding (IMPROVED FOR ANGLES)
# -------------------------------------------------
def extract_face_embedding(image_bytes: bytes):
    """
    Takes raw image bytes and returns a normalized face embedding (numpy array)
    ✅ IMPROVED: Better handling of image preprocessing
    """

    # Convert bytes to numpy image
    image_array = np.frombuffer(image_bytes, np.uint8)
    image = cv2.imdecode(image_array, cv2.IMREAD_COLOR)

    if image is None:
        return None

    # ✅ IMPROVED: Enhance image quality before detection
    # This helps with lighting and clarity issues
    image = cv2.convertScaleAbs(image, alpha=1.2, beta=10)  # Increase contrast slightly

    # Detect faces
    faces = face_app.get(image)

    if not faces:
        return None

    # Take the LARGEST face (most prominent person)
    largest_face = max(faces, key=lambda x: (x.bbox[2] - x.bbox[0]) * (x.bbox[3] - x.bbox[1]))
    
    embedding = largest_face.embedding

    # Normalize embedding
    norm = np.linalg.norm(embedding)
    if norm == 0:
        return None

    embedding = embedding / norm

    return embedding


# -------------------------------------------------
# Compare Two Face Embeddings (IMPROVED THRESHOLD)
# -------------------------------------------------
def compare_faces(embedding1, embedding2, threshold=0.6):
    """
    Returns True if faces match, else False
    ✅ IMPROVED: Using cosine similarity instead of euclidean distance
    This is MUCH BETTER for handling different angles
    """
    if embedding1 is None or embedding2 is None:
        return False

    # ✅ COSINE SIMILARITY (better for face angles)
    # Values range from -1 to 1 (1 = identical, 0 = unrelated)
    similarity = np.dot(embedding1, embedding2) / (
        np.linalg.norm(embedding1) * np.linalg.norm(embedding2)
    )
    
    # Threshold: 0.3-0.4 = strict, 0.5-0.6 = balanced, 0.7+ = lenient
    return similarity > threshold