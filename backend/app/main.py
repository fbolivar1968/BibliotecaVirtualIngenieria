import uuid
from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings


def create_application() -> FastAPI:
    app = FastAPI(
        title=settings.APP_NAME,
        version=settings.APP_VERSION,
        openapi_url=f"{settings.API_V1_PREFIX}/openapi.json",
        docs_url="/docs",
        redoc_url="/redoc",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.middleware("http")
    async def correlation_id_middleware(request: Request, call_next) -> Response:
        correlation_id = request.headers.get("X-Correlation-ID", str(uuid.uuid4()))
        request.state.correlation_id = correlation_id
        response: Response = await call_next(request)
        response.headers["X-Correlation-ID"] = correlation_id
        return response

    @app.get(f"{settings.API_V1_PREFIX}/health/live", tags=["Health"])
    async def liveness_probe() -> dict[str, str]:
        return {"status": "alive", "version": settings.APP_VERSION}

    @app.get(f"{settings.API_V1_PREFIX}/health/ready", tags=["Health"])
    async def readiness_probe() -> dict[str, str]:
        return {"status": "ready", "database": "postgresql+pgvector"}

    return app


app = create_application()

