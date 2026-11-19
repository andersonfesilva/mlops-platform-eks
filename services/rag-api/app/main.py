"""RAG API: question -> input guardrails -> retrieval -> LLM -> output guardrails."""

from __future__ import annotations

import json
import logging
import time
import uuid

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from app.config import Settings
from app.guardrails import check_input, check_output
from app.llm import SYSTEM_PROMPT, ChatModel, OpenAICompatibleChat, build_user_prompt
from app.retriever import BM25Retriever

REFUSAL = "I don't know based on the available documents."

logger = logging.getLogger("rag-api")
logging.basicConfig(level=logging.INFO, format="%(message)s")


class AskRequest(BaseModel):
    question: str = Field(min_length=1, max_length=10_000)


class Source(BaseModel):
    id: int
    document: str


class AskResponse(BaseModel):
    request_id: str
    answer: str
    sources: list[Source]
    redactions: list[str]


def _audit(event: str, **fields: object) -> None:
    # Structured audit log. The question text is never logged, only decisions and metadata.
    logger.info(json.dumps({"event": event, **fields}))


def create_app(
    settings: Settings | None = None,
    retriever: BM25Retriever | None = None,
    model: ChatModel | None = None,
) -> FastAPI:
    settings = settings or Settings.from_env()
    retriever = retriever or BM25Retriever.from_directory(settings.corpus_dir)
    model = model or OpenAICompatibleChat(settings.llm_base_url, settings.llm_model)

    app = FastAPI(title="rag-api", version="0.1.0", docs_url=None, redoc_url=None)

    @app.get("/healthz")
    def healthz() -> dict[str, str]:
        return {"status": "ok"}

    @app.post("/v1/ask", response_model=AskResponse)
    def ask(request: AskRequest) -> AskResponse:
        request_id = str(uuid.uuid4())
        started = time.perf_counter()

        inp = check_input(request.question, max_chars=settings.max_question_chars)
        if not inp.allowed:
            _audit("input_blocked", request_id=request_id, reason=inp.reason)
            raise HTTPException(status_code=400, detail={"request_id": request_id, "reason": inp.reason})

        hits = retriever.search(inp.text, k=settings.top_k)
        if not hits:
            _audit("no_context", request_id=request_id, redactions=inp.redactions)
            return AskResponse(request_id=request_id, answer=REFUSAL, sources=[], redactions=inp.redactions)

        prompt = build_user_prompt(inp.text, [h.chunk.text for h in hits])
        try:
            raw_answer = model.complete(SYSTEM_PROMPT, prompt)
        except Exception as exc:  # noqa: BLE001 - upstream failure must not leak details to the caller
            _audit("llm_error", request_id=request_id, error=type(exc).__name__)
            detail = {"request_id": request_id, "reason": "llm_unavailable"}
            raise HTTPException(status_code=502, detail=detail) from exc

        if raw_answer.strip().startswith("I don't know"):
            _audit("model_refused", request_id=request_id)
            return AskResponse(request_id=request_id, answer=REFUSAL, sources=[], redactions=inp.redactions)

        out = check_output(raw_answer, n_sources=len(hits))
        if not out.allowed:
            _audit("output_blocked", request_id=request_id, reason=out.reason)
            raise HTTPException(status_code=422, detail={"request_id": request_id, "reason": out.reason})

        sources = [Source(id=n, document=hits[n - 1].chunk.source) for n in out.citations]
        redactions = sorted(set(inp.redactions + out.redactions))
        _audit(
            "answered",
            request_id=request_id,
            sources=[s.document for s in sources],
            redactions=redactions,
            latency_ms=round((time.perf_counter() - started) * 1000),
        )
        return AskResponse(
            request_id=request_id,
            answer=out.text,
            sources=sources,
            redactions=redactions,
        )

    return app
