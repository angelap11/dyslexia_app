# ЧитајЛесно — Text Simplification Backend

Python **FastAPI** service that runs **`LVSTCK/domestic-yak-8B-instruct`** for the
Flutter „Поедностави текст“ feature.

```
Flutter  →  POST /v1/simplify  →  FastAPI  →  Domestic-Yak (GPU)  →  simplified_text
```

> **Not production-certified yet.** Real Domestic-Yak inference is only verified
> after you start this API on a CUDA GPU host with model weights downloaded.
> Local CI tests intentionally **do not** fake successful generation.

## Layout

```
backend/
  app/
    main.py          # FastAPI app + /v1/simplify + /health
    config.py        # env settings
    models.py        # request/response schema (Flutter contract)
    auth.py          # optional Bearer API key
    simplify.py      # one-time model load + generation
  tests/
    test_api_validation.py
  requirements.txt
  .env.example
  README.md
```

## 1. Python environment

```bash
cd backend
python -m venv .venv

# Windows PowerShell
.\.venv\Scripts\Activate.ps1

# Linux / macOS
source .venv/bin/activate
```

Python **3.10+** recommended.

## 2. Install dependencies

On a **GPU machine**, install a CUDA build of PyTorch first (match your driver),
then the rest:

```bash
# Example — adjust CUDA version to your host (see https://pytorch.org)
pip install torch --index-url https://download.pytorch.org/whl/cu121

pip install -r requirements.txt
```

On a CPU-only laptop you can still install FastAPI/pytest pieces for API
validation tests, but **4-bit Domestic-Yak inference will not run**.

## 3. Environment variables

```bash
copy .env.example .env   # Windows
# cp .env.example .env   # Linux/macOS
```

| Variable | Required | Purpose |
|---|---|---|
| `HF_TOKEN` | Often yes | Hugging Face token to download the model |
| `SIMPLIFY_API_KEY` | Optional | If set, Flutter must send `Authorization: Bearer …` |
| `SIMPLIFY_MODEL_ID` | No | Default `LVSTCK/domestic-yak-8B-instruct` |
| `SIMPLIFY_SKIP_MODEL_LOAD` | No | `true` = API-only mode (no weights; `/v1/simplify` → 503) |
| `SIMPLIFY_HOST` / `SIMPLIFY_PORT` | No | Bind defaults `0.0.0.0:8000` |

Load `.env` before start (uvicorn does not auto-load it):

```bash
# Windows PowerShell example
Get-Content .env | ForEach-Object {
  if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
  $k,$v = $_.Split('=',2); Set-Item -Path "Env:$k" -Value $v
}
```

Or use `python-dotenv` / your process manager.

**Never** put HF tokens or API keys in Flutter source or commit them to git.

## 4. Start FastAPI

From the `backend/` directory (so `app` is importable):

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

- First start downloads / loads the 8B model in **4-bit NF4** (BitsAndBytes,
  FP16 compute, double quant). This can take several minutes.
- Model stays in memory for subsequent requests (not reloaded per call).
- Check readiness: `GET http://localhost:8000/health`

## 5. Test `/v1/simplify` (Macedonian example)

```bash
curl -X POST "http://localhost:8000/v1/simplify" ^
  -H "Content-Type: application/json" ^
  -H "Authorization: Bearer YOUR_API_KEY" ^
  -d "{\"text\":\"Денес времето е многу убаво и целото небо е ведро.\",\"model\":\"LVSTCK/domestic-yak-8B-instruct\",\"language\":\"mk\",\"prompt_id\":\"mk_dyslexia_simplify_v1\",\"system_prompt\":\"Поедностави го следниот текст на македонски јазик.\\n\\nПравила:\\n* користи пократки и поедноставни реченици;\\n* замени ги сложените зборови со поедноставни кога тоа е можно;\\n* не додавај нови информации;\\n* не изоставувај важни информации;\\n* задржи го значењето на оригиналниот текст;\\n* текстот треба да биде природен и граматички правилен на македонски јазик;\\n* врати само поедноставен текст, без дополнителни објаснувања.\"}"
```

Expected success body:

```json
{ "simplified_text": "..." }
```

Linux/macOS `curl` uses `\` line continuations instead of `^`.

## 6. GPU requirements

| Item | Guidance |
|---|---|
| GPU | NVIDIA CUDA GPU |
| VRAM | Roughly **≥ 8–10 GB** for 8B 4-bit NF4 (more is safer) |
| Stack | CUDA-capable `torch` + `bitsandbytes` |
| CPU-only | API starts, but inference returns **503** (by design) |

This matches the diploma experimental stack as closely as practical:
Transformers + BitsAndBytes 4-bit NF4 + FP16 compute + double quantization;
`max_new_tokens=512`, `do_sample=false`; Llama 3.1 chat template via
`tokenizer.apply_chat_template`.

## 7. Point Flutter at this backend

In the Flutter project `.env`:

```env
TEXT_SIMPLIFY_BASE_URL=http://<GPU_HOST_IP>:8000
TEXT_SIMPLIFY_API_KEY=YOUR_API_KEY
TEXT_SIMPLIFY_USE_MOCK=false
```

- `BASE_URL` must be the origin only (no `/v1/simplify` suffix).
- Flutter already calls `POST {BASE_URL}/v1/simplify`.
- Rebuild / restart the app after changing `.env`.
- For a physical phone, use the LAN IP of the GPU machine (not `localhost`).

## Local tests (no GPU)

```bash
cd backend
set SIMPLIFY_SKIP_MODEL_LOAD=true
pytest -q
```

These tests check validation, auth, and that simplify returns **503** when the
model is not loaded — they do **not** claim Domestic-Yak works.

## What still needs a GPU

1. Successful model download / load
2. Real `POST /v1/simplify` returning Macedonian simplified text
3. End-to-end check from the Flutter app with `TEXT_SIMPLIFY_USE_MOCK=false`

## Next step for deployment (not done in this phase)

Choose a GPU host, install CUDA + deps, set secrets as env vars, expose HTTPS
(or a tunnel), then set Flutter `TEXT_SIMPLIFY_BASE_URL` to that public origin.
Do not deploy until GPU smoke tests pass.
