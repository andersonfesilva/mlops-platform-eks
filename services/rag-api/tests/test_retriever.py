from pathlib import Path

from app.retriever import BM25Retriever, Chunk, chunk_markdown

DATA_DIR = Path(__file__).resolve().parents[1] / "data"


def test_relevant_document_ranks_first():
    retriever = BM25Retriever.from_directory(DATA_DIR)
    hits = retriever.search("IMDSv2 hop limit metadata credentials")
    assert hits
    assert hits[0].chunk.source == "imds-hardening.md"


def test_unrelated_question_returns_nothing():
    retriever = BM25Retriever.from_directory(DATA_DIR)
    assert retriever.search("best pizza recipe in Naples") == []


def test_k_limits_results():
    retriever = BM25Retriever([Chunk("a.md", "kubernetes pods"), Chunk("b.md", "kubernetes nodes")])
    assert len(retriever.search("kubernetes", k=1, min_score=0.0)) == 1


def test_chunking_respects_max_chars():
    text = "\n\n".join(f"## Section {i}\n" + "word " * 50 for i in range(10))
    chunks = chunk_markdown("doc.md", text, max_chars=400)
    assert len(chunks) > 1
    assert all(c.source == "doc.md" for c in chunks)
