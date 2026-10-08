from fastapi import FastAPI

from .api import auth, users

app = FastAPI(title="LinuxTraining", docs_url="/api/docs", openapi_url="/api/openapi.json", redoc_url=None)
app.include_router(auth.router)
app.include_router(users.router)


@app.get("/api/health")
def health() -> dict:
    return {"status": "ok"}
