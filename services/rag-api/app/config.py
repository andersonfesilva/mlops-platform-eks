from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    llm_base_url: str
    llm_model: str
    corpus_dir: str
    top_k: int
    max_question_chars: int

    @classmethod
    def from_env(cls) -> Settings:
        return cls(
            llm_base_url=os.environ.get("LLM_BASE_URL", "http://localhost:8080/openai/v1"),
            llm_model=os.environ.get("LLM_MODEL", "llm"),
            corpus_dir=os.environ.get("CORPUS_DIR", "data"),
            top_k=int(os.environ.get("TOP_K", "3")),
            max_question_chars=int(os.environ.get("MAX_QUESTION_CHARS", "2000")),
        )
