#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

from jsonschema import validate


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--schema", required=True)
    parser.add_argument("--input", required=True)
    args = parser.parse_args()

    schema = json.loads(Path(args.schema).read_text(encoding="utf-8"))
    payload = json.loads(Path(args.input).read_text(encoding="utf-8"))

    validate(instance=payload, schema=schema)
    print(f"schema validation passed: {args.input}")


if __name__ == "__main__":
    main()
