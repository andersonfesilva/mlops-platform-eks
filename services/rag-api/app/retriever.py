"""Small, dependency-free BM25 retriever over a directory of Markdown files.

Good enough for a few hundred documents and fully deterministic, which keeps
tests reliable. Swap it for a vector store (OpenSearch, pgvector) behind the
same `search()` interface when the corpus grows.
"""

from __future__ import annotations

import math
import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

_TOKEN = re.compile(r"[a-z0-9]+")
_STOPWORDS = frozenset(
    "a an and are as at be by do does for from how i in is it of on or should the this to what when "
    "where which who why with you your".split()
)


def tokenize(text: str) -> list[str]:
    return [t for t in _TOKEN.findall(text.lower()) if t not in _STOPWORDS and len(t) > 1]


@dataclass(frozen=True)
class Chunk:
    source: str
    text: str


@dataclass(frozen=True)
class Hit:
    chunk: Chunk
    score: float


def chunk_markdown(source: str, text: str, max_chars: int = 800) -> list[Chunk]:
    """Split on headings and blank lines, then pack paragraphs up to max_chars."""
    blocks = [b.strip() for b in re.split(r"\n(?=#)|\n\s*\n", text) if b.strip()]
    chunks: list[Chunk] = []
    current = ""
    for block in blocks:
        if current and len(current) + len(block) + 2 > max_chars:
            chunks.append(Chunk(source, current))
            current = block
        else:
            current = f"{current}\n\n{block}" if current else block
    if current:
        chunks.append(Chunk(source, current))
    return chunks


class BM25Retriever:
    def __init__(self, chunks: list[Chunk], k1: float = 1.5, b: float = 0.75) -> None:
        self.chunks = chunks
        self.k1 = k1
        self.b = b
        self._tfs = [Counter(tokenize(c.text)) for c in chunks]
        self._lens = [sum(tf.values()) for tf in self._tfs]
        self._avg_len = (sum(self._lens) / len(self._lens)) if self._lens else 0.0
        df: Counter[str] = Counter()
        for tf in self._tfs:
            df.update(tf.keys())
        n = len(chunks)
        self._idf = {term: math.log(1 + (n - d + 0.5) / (d + 0.5)) for term, d in df.items()}

    @classmethod
    def from_directory(cls, directory: str | Path) -> BM25Retriever:
        chunks: list[Chunk] = []
        for path in sorted(Path(directory).glob("**/*.md")):
            chunks.extend(chunk_markdown(path.name, path.read_text(encoding="utf-8")))
        return cls(chunks)

    def search(self, query: str, k: int = 3, min_score: float = 0.5) -> list[Hit]:
        terms = tokenize(query)
        if not terms or not self.chunks:
            return []
        hits: list[Hit] = []
        for chunk, tf, length in zip(self.chunks, self._tfs, self._lens, strict=True):
            score = 0.0
            for term in terms:
                freq = tf.get(term, 0)
                if not freq:
                    continue
                norm = freq * (self.k1 + 1) / (freq + self.k1 * (1 - self.b + self.b * length / self._avg_len))
                score += self._idf.get(term, 0.0) * norm
            if score >= min_score:
                hits.append(Hit(chunk, score))
        hits.sort(key=lambda h: h.score, reverse=True)
        return hits[:k]
