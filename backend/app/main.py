"""FastAPI entrypoint — POST /v1/simplify for ЧитајЛесно Flutter client."""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.responses import JSONResponse
from pydantic import ValidationError

from .auth import require_api_key
from .config import get_settings
from .models import SimplifyRequest, SimplifyResponse
from .simplify import (
    EmptyGenerationError,
    ModelNotReadyError,
    engine,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(_app: FastAPI):
    settings = get_settings()
    logger.info(
        "Starting simplify API (model_id=%s, skip_load=%s)",
        settings.model_id,
        settings.skip_model_load,
    )
    engine.load(settings)
    if engine.ready:
        logger.info("Inference engine ready")
    else:
        logger.warning("Inference engine NOT ready: %s", engine.load_error)
    yield


app = FastAPI(
    title="ЧитајЛесно Text Simplification API",
    description=(
        "Backend for LVSTCK/domestic-yak-8B-instruct. "
        "Compatible with the Flutter TextSimplificationService contract."
    ),
    version="0.1.0",
    lifespan=lifespan,
)


@app.get("/health")
def health() -> dict:
    return {
        "status": "ok",
        "model_ready": engine.ready,
        "model_id": get_settings().model_id,
        "detail": None if engine.ready else engine.load_error,
    }


@app.post(
    "/v1/simplify",
    response_model=SimplifyResponse,
    dependencies=[Depends(require_api_key)],
)
def simplify(payload: SimplifyRequest) -> SimplifyResponse:
    try:
        simplified = engine.simplify(
            system_prompt=payload.system_prompt,
            text=payload.text,
        )
    except ModelNotReadyError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except EmptyGenerationError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(exc),
        ) from exc
    except Exception as exc:  # noqa: BLE001 — never crash the worker on one bad request
        logger.exception("Unhandled simplify error")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Simplification failed: {exc}",
        ) from exc

    return SimplifyResponse(simplified_text=simplified)


@app.exception_handler(ValidationError)
async def validation_exception_handler(_request, exc: ValidationError):
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"detail": exc.errors()},
    )
