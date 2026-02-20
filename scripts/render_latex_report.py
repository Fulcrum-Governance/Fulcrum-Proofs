#!/usr/bin/env python3
"""Render a LaTeX report from JSON payload and template."""

import argparse
import json
from pathlib import Path


def esc(text: str) -> str:
    m = {
        "\\": "\\\\textbackslash{}",
        "&": "\\\\&",
        "%": "\\\\%",
        "$": "\\\\$",
        "#": "\\\\#",
        "_": "\\\\_",
        "{": "\\\\{",
        "}": "\\\\}",
        "~": "\\\\textasciitilde{}",
        "^": "\\\\textasciicircum{}",
    }
    return "".join(m.get(c, c) for c in text)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--template", required=True)
    p.add_argument("--input", required=True)
    p.add_argument("--output", required=True)
    args = p.parse_args()

    template = Path(args.template).read_text(encoding="utf-8")
    data = json.loads(Path(args.input).read_text(encoding="utf-8"))

    out = template
    out = out.replace("{{TITLE}}", esc(data.get("title", "Fulcrum Proof Report")))
    out = out.replace("{{BODY}}", esc(data.get("body", "")))

    Path(args.output).write_text(out, encoding="utf-8")


if __name__ == "__main__":
    main()
