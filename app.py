from fastapi import FastAPI
from pydantic import BaseModel
from transformers import TrOCRProcessor, VisionEncoderDecoderModel
from PIL import Image
import base64
import cv2
import numpy as np
import re

app = FastAPI()

processor = TrOCRProcessor.from_pretrained('microsoft/trocr-base-printed')
model = VisionEncoderDecoderModel.from_pretrained('microsoft/trocr-base-printed')

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

    image = cv2.cvtColor(image, cv2.COLOR_GRAY2RGB)
    pil_image = Image.fromarray(image)

    pixel_values = processor(images=pil_image, return_tensors="pt").pixel_values
    generated_ids = model.generate(pixel_values)
    text = processor.batch_decode(generated_ids, skip_special_tokens=True)[0]

    text = re.sub(r'[^0-9A-Z]', '', text.upper())

    return {
        "text": text
    }

# ✅ Health check endpoint
@app.get("/health")
def health():
    return {
        "status": "ok"
    }
