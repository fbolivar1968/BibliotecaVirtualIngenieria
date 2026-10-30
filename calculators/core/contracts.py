"""
Contrato estándar del motor normativo determinístico (SAD §7.2 y DDD §1.1).
Regla obligatoria: Prohibido usar float para decisiones de tolerancia; usar Decimal.
"""

from datetime import datetime, timezone
from decimal import Decimal
from typing import Any
from uuid import UUID, uuid4
from pydantic import BaseModel, ConfigDict, Field


class NormativeTraceability(BaseModel):
    """Trazabilidad obligatoria de norma, edición, página/tabla y versión algorítmica."""

    model_config = ConfigDict(frozen=True)

    calculator_code: str
    calculator_version: str
    formula_code: str
    formula_version: str
    source_code_hash: str
    standard_code: str
    standard_edition: str
    source_page: int | None = None
    source_table: str | None = None
    source_section: str | None = None


class CalculationWarning(BaseModel):
    """Advertencia técnica emitida durante la evaluación determinística."""

    model_config = ConfigDict(frozen=True)

    code: str
    severity: str = Field(default="WARNING", pattern="^(INFO|WARNING|CRITICAL)$")
    message: str
    field: str | None = None


class StandardCalculationEnvelope(BaseModel):
    """Contrato común de salida de cualquier calculadora normativa (SAD §7.2)."""

    model_config = ConfigDict(frozen=True)

    execution_id: UUID = Field(default_factory=uuid4)
    executed_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    request: dict[str, Any]
    result: dict[str, Decimal | str | int | bool]
    tolerances: dict[str, Decimal | str] = Field(default_factory=dict)
    warnings: list[CalculationWarning] = Field(default_factory=list)
    traceability: NormativeTraceability

