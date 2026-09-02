from fastapi import FastAPI
from pydantic import BaseModel
import ddddocr
import base64
import re
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ocr")

app = FastAPI()

ocr = ddddocr.DdddOcr(show_ad=False)

# Update to r'[^A-Z]' if captchas are confirmed letters-only
ALLOWED_CHARS = re.compile(r'[^0-9A-Z]')

class ImageRequest(BaseModel):
    base64Image: str

@app.post("/ocr")
def read_captcha(req: ImageRequest):
    image_bytes = base64.b64decode(req.base64Image)

    raw_text = ocr.classification(image_bytes)
    logger.info(f"raw OCR output: {raw_text!r}")

    text = ALLOWED_CHARS.sub('', raw_text.upper())

    return {
        "text": text
    }

# ✅ Health check endpoint
@app.get("/health")
def health():
    return {
        "status": "ok"
    }
