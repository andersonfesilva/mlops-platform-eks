"""Input and output guardrails for the RAG API.

The checks are deterministic and dependency-free on purpose: they run on every
request, they are cheap, and they are easy to audit and unit-test. They are a
first line of defence, not a complete solution (see docs/threat-model.md).
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

# --- Prompt injection ---------------------------------------------------------

# Phrases commonly used to override system instructions or exfiltrate the prompt.
# Matching is case-insensitive and whitespace-tolerant.
_INJECTION_PATTERNS: tuple[re.Pattern[str], ...] = tuple(
    re.compile(p, re.IGNORECASE)
    for p in (
        r"ignore\s+(all\s+|any\s+)?(the\s+)?(previous|prior|above)\s+(instructions|rules|prompts?)",
        r"disregard\s+(all\s+|any\s+)?(the\s+)?(previous|prior|above|system)\s+(instructions|rules|prompts?)",
        r"(reveal|show|print|repeat)\s+(me\s+)?(your|the)\s+(system\s+prompt|hidden\s+instructions|instructions)",
        r"you\s+are\s+now\s+(in\s+)?(dan|developer\s+mode|jailbreak)",
        r"pretend\s+(that\s+)?you\s+(have\s+no|are\s+not\s+bound\s+by)\s+(rules|restrictions|guidelines)",
        r"</?\s*(system|assistant)\s*>",
        r"\bBEGIN\s+SYSTEM\s+PROMPT\b",
    )
)

# --- Sensitive data -----------------------------------------------------------

_EMAIL = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")
_CPF = re.compile(r"\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b")
_CARD_CANDIDATE = re.compile(r"\b(?:\d[ -]?){13,19}\b")

# Credentials that must never appear in a model answer.
_SECRET_PATTERNS: dict[str, re.Pattern[str]] = {
    "aws_access_key_id": re.compile(r"\b(AKIA|ASIA)[0-9A-Z]{16}\b"),
    "private_key": re.compile(r"-----BEGIN (RSA |EC |OPENSSH |)PRIVATE KEY-----"),
    "github_token": re.compile(r"\bgh[pousr]_[A-Za-z0-9]{36,}\b"),
    "generic_bearer": re.compile(r"\bBearer\s+[A-Za-z0-9\-._~+/]{20,}=*", re.IGNORECASE),
}

_CITATION = re.compile(r"\[(\d+)\]")


def _luhn_valid(digits: str) -> bool:
    total = 0
    for i, ch in enumerate(reversed(digits)):
        n = int(ch)
        if i % 2 == 1:
            n *= 2
            if n > 9:
                n -= 9
        total += n
    return total % 10 == 0


def redact_pii(text: str) -> tuple[str, list[str]]:
    """Mask e-mails, CPFs and Luhn-valid card numbers. Returns (text, kinds found)."""
    found: list[str] = []

    def _card(match: re.Match[str]) -> str:
        digits = re.sub(r"\D", "", match.group(0))
        if 13 <= len(digits) <= 19 and _luhn_valid(digits):
            found.append("card_number")
            return "[REDACTED_CARD]"
        return match.group(0)

    text = _CARD_CANDIDATE.sub(_card, text)

    if _EMAIL.search(text):
        found.append("email")
        text = _EMAIL.sub("[REDACTED_EMAIL]", text)

    if _CPF.search(text):
        found.append("cpf")
        text = _CPF.sub("[REDACTED_CPF]", text)

    return text, found


def find_secrets(text: str) -> list[str]:
    """Return the kinds of credentials found in text."""
    return [kind for kind, pattern in _SECRET_PATTERNS.items() if pattern.search(text)]


# --- Results ------------------------------------------------------------------


@dataclass
class InputCheck:
    allowed: bool
    text: str
    reason: str | None = None
    redactions: list[str] = field(default_factory=list)


@dataclass
class OutputCheck:
    allowed: bool
    text: str
    reason: str | None = None
    redactions: list[str] = field(default_factory=list)
    citations: list[int] = field(default_factory=list)


# --- Guards -------------------------------------------------------------------


def check_input(question: str, max_chars: int = 2000) -> InputCheck:
    """Validate a user question before it reaches retrieval or the model."""
    stripped = question.strip()
    if not stripped:
        return InputCheck(False, question, reason="empty_question")

    if len(stripped) > max_chars:
        return InputCheck(False, question, reason="question_too_long")

    for pattern in _INJECTION_PATTERNS:
        if pattern.search(stripped):
            return InputCheck(False, question, reason="prompt_injection_suspected")

    if find_secrets(stripped):
        # Never forward credentials to the model or to logs.
        return InputCheck(False, question, reason="credential_in_input")

    redacted, kinds = redact_pii(stripped)
    return InputCheck(True, redacted, redactions=kinds)


def check_output(answer: str, n_sources: int) -> OutputCheck:
    """Validate a model answer before it is returned to the caller.

    Rules:
    * block answers that contain credentials;
    * mask PII the model may have echoed;
    * require at least one citation, and every citation must point to a real
      retrieved source (1..n_sources). Ungrounded answers are rejected.
    """
    if find_secrets(answer):
        return OutputCheck(False, answer, reason="credential_in_output")

    redacted, kinds = redact_pii(answer)

    citations = sorted({int(n) for n in _CITATION.findall(redacted)})
    if not citations:
        return OutputCheck(False, redacted, reason="ungrounded_answer", redactions=kinds)

    if any(n < 1 or n > n_sources for n in citations):
        return OutputCheck(False, redacted, reason="invalid_citation", redactions=kinds, citations=citations)

    return OutputCheck(True, redacted, redactions=kinds, citations=citations)
