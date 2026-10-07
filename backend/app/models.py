"""Pydantic request/response models matching the Flutter contract."""

from __future__ import annotations

from pydantic import BaseModel, Field, field_validator

EXPECTED_MODEL = "LVSTCK/domestic-yak-8B-instruct"
SUPPORTED_LANGUAGE = "mk"


class SimplifyRequest(BaseModel):
    text: str = Field(..., description="Original Macedonian text to simplify")
    model: str = Field(default=EXPECTED_MODEL)
    language: str = Field(default=SUPPORTED_LANGUAGE)
    prompt_id: str = Field(default="mk_dyslexia_simplify_v1")
    system_prompt: str = Field(
        ...,
        description="Instruction prompt from the Flutter client (experimental eval)",
    )

    @field_validator("text")
    @classmethod
    def text_must_not_be_blank(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("text must not be empty")
        return cleaned

    @field_validator("system_prompt")
    @classmethod
    def system_prompt_must_not_be_blank(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("system_prompt must not be empty")
        return cleaned

    @field_validator("language")
    @classmethod
    def language_must_be_mk(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized != SUPPORTED_LANGUAGE:
            raise ValueError(f"unsupported language '{value}'; only 'mk' is supported")
        return normalized

    @field_validator("model")
    @classmethod
    def model_must_match(cls, value: str) -> str:
        cleaned = value.strip()
        if cleaned != EXPECTED_MODEL:
            raise ValueError(
                f"unsupported model '{value}'; expected '{EXPECTED_MODEL}'"
            )
        return cleaned


class SimplifyResponse(BaseModel):
    simplified_text: str
