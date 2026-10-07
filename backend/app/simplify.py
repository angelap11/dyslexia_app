"""Domestic-Yak inference — model loaded once per process."""

from __future__ import annotations

import logging
from typing import Any

from .config import Settings

logger = logging.getLogger(__name__)

EXPECTED_MODEL = "LVSTCK/domestic-yak-8B-instruct"

# Exact experimental-evaluation prompts (diploma). Flutter's system_prompt is ignored.
EXPERIMENTAL_SYSTEM_PROMPT = (
    "Ти си асистент за поедноставување текст на македонски јазик.\n"
    "Твојата задача е да го направиш текстот полесен за читање и разбирање,\n"
    "без да го промениш неговото значење."
)

EXPERIMENTAL_USER_PROMPT_TEMPLATE = """Поедностави го следниот текст на македонски јазик за полесно да може
да го прочита и разбере дете со тешкотии при читањето.

Правила:
* Користи пократки и поедноставни реченици.
* Замени ги сложените зборови со поедноставни зборови каде што е можно.
* Не додавај информации што ги нема во оригиналниот текст.
* Не отстранувај важни информации.
* Задржи го оригиналното значење.
* Врати само поедноставен текст, без дополнителни објаснувања.

Текст:
{text}"""


class ModelNotReadyError(RuntimeError):
    """Raised when weights are not loaded (no GPU / skip flag / load failure)."""


class EmptyGenerationError(RuntimeError):
    """Raised when the model returns blank output."""


class SimplificationEngine:
    """Holds tokenizer + model for the lifetime of the FastAPI process."""

    def __init__(self) -> None:
        self._tokenizer: Any | None = None
        self._model: Any | None = None
        self._ready: bool = False
        self._load_error: str | None = None

    @property
    def ready(self) -> bool:
        return self._ready

    @property
    def load_error(self) -> str | None:
        return self._load_error

    def load(self, settings: Settings) -> None:
        if settings.skip_model_load:
            self._load_error = (
                "Model load skipped (SIMPLIFY_SKIP_MODEL_LOAD=true). "
                "Inference is unavailable in this process."
            )
            logger.warning(self._load_error)
            return

        try:
            import torch
            from transformers import (
                AutoModelForCausalLM,
                AutoTokenizer,
                BitsAndBytesConfig,
            )
        except ImportError as exc:
            self._load_error = (
                f"Missing ML dependencies ({exc}). Install requirements.txt on a GPU host."
            )
            logger.error(self._load_error)
            return

        if not torch.cuda.is_available():
            self._load_error = (
                "CUDA is not available. Domestic-Yak 4-bit inference requires a GPU. "
                "This process will reject /v1/simplify with HTTP 503."
            )
            logger.error(self._load_error)
            return

        model_id = settings.model_id or EXPECTED_MODEL
        logger.info("Loading model %s (4-bit NF4, double quant, fp16 compute)…", model_id)

        try:
            tokenizer = AutoTokenizer.from_pretrained(
                model_id,
                token=settings.hf_token,
                trust_remote_code=False,
            )

            # Experimental diploma setup (as practical):
            # 4-bit + NF4 + FP16 compute + double quantization via BitsAndBytes.
            bnb_config = BitsAndBytesConfig(
                load_in_4bit=True,
                bnb_4bit_quant_type="nf4",
                bnb_4bit_compute_dtype=torch.float16,
                bnb_4bit_use_double_quant=True,
            )

            model = AutoModelForCausalLM.from_pretrained(
                model_id,
                quantization_config=bnb_config,
                device_map="auto",
                token=settings.hf_token,
                trust_remote_code=False,
            )
            model.eval()

            self._tokenizer = tokenizer
            self._model = model
            self._ready = True
            self._load_error = None
            logger.info("Model ready on %s", torch.cuda.get_device_name(0))
        except Exception as exc:  # noqa: BLE001 — surface load failure without crash
            self._ready = False
            self._tokenizer = None
            self._model = None
            self._load_error = f"Failed to load model: {exc}"
            logger.exception("Model load failed")

    def simplify(self, *, system_prompt: str, text: str) -> str:
        """Simplify [text] with the fixed experimental prompt structure.

        [system_prompt] from Flutter is accepted for API compatibility but ignored
        so inference matches the diploma evaluation exactly.
        """
        if not self._ready or self._tokenizer is None or self._model is None:
            raise ModelNotReadyError(
                self._load_error
                or "Model is not loaded. Start the API on a CUDA GPU host."
            )

        import torch

        # Diploma experimental messages — not Flutter's system_prompt.
        _ = system_prompt
        user_content = EXPERIMENTAL_USER_PROMPT_TEMPLATE.format(text=text.strip())
        messages = [
            {"role": "system", "content": EXPERIMENTAL_SYSTEM_PROMPT},
            {"role": "user", "content": user_content},
        ]

        prompt = self._tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True,
        )
        inputs = self._tokenizer(prompt, return_tensors="pt")
        device = next(self._model.parameters()).device
        inputs = {k: v.to(device) for k, v in inputs.items()}
        prompt_len = inputs["input_ids"].shape[-1]

        try:
            with torch.inference_mode():
                output_ids = self._model.generate(
                    **inputs,
                    max_new_tokens=512,
                    do_sample=False,
                    pad_token_id=self._tokenizer.eos_token_id,
                )
        except Exception as exc:  # noqa: BLE001
            logger.exception("Generation failed")
            raise RuntimeError(f"Generation failed: {exc}") from exc

        new_tokens = output_ids[0][prompt_len:]
        simplified = self._tokenizer.decode(
            new_tokens, skip_special_tokens=True
        ).strip()

        if not simplified:
            raise EmptyGenerationError("Model returned empty simplified text")

        return simplified


# Process-wide singleton — loaded once in FastAPI lifespan.
engine = SimplificationEngine()
