"""API validation tests — no GPU / no model weights required."""

from __future__ import annotations

import os

import pytest

# Must be set before importing the FastAPI app so lifespan skips GPU load.
os.environ["SIMPLIFY_SKIP_MODEL_LOAD"] = "true"
os.environ.pop("SIMPLIFY_API_KEY", None)

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402

EXPERIMENTAL_PROMPT = """Поедностави го следниот текст на македонски јазик.

Правила:
* користи пократки и поедноставни реченици;
* замени ги сложените зборови со поедноставни кога тоа е можно;
* не додавај нови информации;
* не изоставувај важни информации;
* задржи го значењето на оригиналниот текст;
* текстот треба да биде природен и граматички правилен на македонски јазик;
* врати само поедноставен текст, без дополнителни објаснувања.
"""


@pytest.fixture()
def client():
    with TestClient(app) as test_client:
        yield test_client


def _payload(**overrides):
    body = {
        "text": "Денес времето е многу убаво и сончево.",
        "model": "LVSTCK/domestic-yak-8B-instruct",
        "language": "mk",
        "prompt_id": "mk_dyslexia_simplify_v1",
        "system_prompt": EXPERIMENTAL_PROMPT,
    }
    body.update(overrides)
    return body


def test_health_reports_model_not_ready_when_skipped(client: TestClient):
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["model_ready"] is False


def test_simplify_rejects_empty_text(client: TestClient):
    response = client.post("/v1/simplify", json=_payload(text="   "))
    assert response.status_code == 422


def test_simplify_rejects_unsupported_language(client: TestClient):
    response = client.post("/v1/simplify", json=_payload(language="en"))
    assert response.status_code == 422


def test_simplify_rejects_wrong_model(client: TestClient):
    response = client.post(
        "/v1/simplify",
        json=_payload(model="some-other-model"),
    )
    assert response.status_code == 422


def test_simplify_returns_503_when_model_not_loaded(client: TestClient):
    """Without GPU weights we must NOT pretend inference succeeded."""
    response = client.post("/v1/simplify", json=_payload())
    assert response.status_code == 503
    assert "detail" in response.json()


def test_api_key_required_when_configured(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("SIMPLIFY_API_KEY", "test-secret")
    # Re-import settings cache is sticky — clear and rebuild auth path via header.
    from app.config import get_settings

    get_settings.cache_clear()

    with TestClient(app) as client:
        missing = client.post("/v1/simplify", json=_payload())
        assert missing.status_code == 401

        ok_auth_but_no_model = client.post(
            "/v1/simplify",
            json=_payload(),
            headers={"Authorization": "Bearer test-secret"},
        )
        # Auth passes; model still skipped → 503 (not 200 fake success).
        assert ok_auth_but_no_model.status_code == 503

    monkeypatch.delenv("SIMPLIFY_API_KEY", raising=False)
    get_settings.cache_clear()
