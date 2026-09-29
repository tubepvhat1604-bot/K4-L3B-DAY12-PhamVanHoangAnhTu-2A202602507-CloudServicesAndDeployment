# ═══════════════════════════════════════════════════════════════════
# CP2 — Dockerfile production: multi-stage, slim, non-root, healthcheck
# Build:  docker build -t day12-agent:prod .
# ═══════════════════════════════════════════════════════════════════

# ---------- Stage 1: builder — cài thư viện ----------
FROM python:3.11-slim AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /build

# requirements.txt copy riêng và cài trước để tận dụng cache
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---------- Stage 2: runtime — chỉ chứa thứ cần để chạy ----------
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

COPY --from=builder /install /usr/local

RUN useradd --create-home --uid 10001 agent

WORKDIR /app

COPY --chown=agent:agent app ./app
COPY --chown=agent:agent utils ./utils

USER agent

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import os, urllib.request; urllib.request.urlopen('http://127.0.0.1:' + os.environ.get('PORT', '8000') + '/health', timeout=4).read()" || exit 1

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
