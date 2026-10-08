import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI

from .api import admin, attempts, auth, review, scenarios, terminal_ws, users
from .services.scheduler import scheduler

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")


@asynccontextmanager
async def lifespan(app: FastAPI):
    run = os.environ.get("LT_DISABLE_SCHEDULER") != "1"  # tests drive the scheduler by hand
    if run:
        scheduler.start()
    yield
    if run:
        scheduler.stop()


app = FastAPI(title="LinuxTraining", docs_url="/api/docs", openapi_url="/api/openapi.json", redoc_url=None, lifespan=lifespan)
for r in (auth.router, users.router, scenarios.router, scenarios.admin, attempts.router, admin.router, review.router, terminal_ws.router):
    app.include_router(r)


@app.get("/api/health")
def health() -> dict:
    return {"status": "ok"}
