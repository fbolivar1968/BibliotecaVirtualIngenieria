from celery import Celery
from app.core.config import settings

celery_app = Celery(
    "fobol_engineering_worker",
    broker=settings.REDIS_URL,
    backend=settings.REDIS_URL,
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_routes={
        "app.workers.tasks.document.*": {"queue": "documents_ocr_rag"},
        "app.workers.tasks.reports.*": {"queue": "reports_generation"},
    },
)

