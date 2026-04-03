from fastapi import FastAPI
from pydantic import BaseModel
import easyocr
import base64
import cv2
import numpy as np

app = FastAPI()

reader = easyocr.Reader(
    ['en'],
    gpu=False
)

class ImageRequest(BaseModel):
    base64Image: str

@app.post("/ocr")
def read_captcha(req: ImageRequest):
    image_bytes = base64.b64decode(req.base64Image)
    np_arr = np.frombuffer(image_bytes, np.uint8)
    image = cv2.imdecode(np_arr, cv2.IMREAD_GRAYSCALE)

    image = cv2.resize(image, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
    image = cv2.threshold(image, 0, 255,
                           cv2.THRESH_BINARY + cv2.THRESH_OTSU)[1]

    result = reader.readtext(
        image,
        allowlist='0123456789',
        detail=0
    )

    return {
        "text": "".join(result)
    }

# ✅ Health check endpoint
@app.get("/health")
def health():
    return {
        "status": "ok"
    }