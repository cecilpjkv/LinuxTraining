FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt requirements-dev.txt ./
ARG DEV=0
RUN pip install --no-cache-dir -r $([ "$DEV" = 1 ] && echo requirements-dev.txt || echo requirements.txt)
COPY . .
# the API listens on 8000 inside the compose network; the web container proxies to it
CMD ["sh", "-c", "alembic upgrade head && { python -m app.cli seed || true; } && exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --proxy-headers --forwarded-allow-ips='*'"]
