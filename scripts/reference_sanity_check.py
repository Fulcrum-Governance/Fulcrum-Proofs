#!/usr/bin/env python3
"""Flag likely citation metadata issues from plain-text references."""

import argparse
import re
from pathlib import Path

ARXIV_RE = re.compile(r"arXiv\s*:?\s*(\d{4}\.\d{4,5})(v\d+)?", re.IGNORECASE)
YEAR_RE = re.compile(r"\((19|20)\d{2}\)")
ENTRY_START_RE = re.compile(r"^\[(\d+)\]\s+")


def infer_year_from_arxiv(aid: str):
    yy = int(aid[:2])
    if yy <= 30:
        return 2000 + yy
    return 1900 + yy


def parse_entries(text: str):
    entries = []
    current = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        if ENTRY_START_RE.match(line):
            if current:
                entries.append(" ".join(current))
                current = []
            current.append(line)
        elif current:
            current.append(line)
    if current:
        entries.append(" ".join(current))
    return entries


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    args = parser.parse_args()

    txt = Path(args.input).read_text(encoding="utf-8", errors="ignore")
    entries = parse_entries(txt)

    issues = 0
    for ln in entries:
        m = ARXIV_RE.search(ln)
        if not m:
            continue
        aid = m.group(1)
        inferred = infer_year_from_arxiv(aid)
        y = YEAR_RE.search(ln)
        stated = int(y.group(0).strip("()")) if y else None
        if stated is not None and stated != inferred:
            issues += 1
            print(f"[YEAR_MISMATCH] stated={stated}, arxiv_inferred={inferred}, id={aid}")
            print(f"  line: {ln}")

    if issues == 0:
        print("No arXiv year mismatches detected by heuristic checks.")


if __name__ == "__main__":
    main()
