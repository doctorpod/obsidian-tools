#!/usr/bin/env python3
import sys
import random

DEFAULT_PATH = "/Users/andy/Obsidian/notes-personal/lib/2025/Daily journal ticklers.md"


def main():
    path = sys.argv[1] if len(sys.argv) == 2 else DEFAULT_PATH

    try:
        with open(path) as f:
            raw = [line.strip() for line in f if line.strip() and not line.startswith("#")]
    except FileNotFoundError:
        print(f"File not found: {path}", file=sys.stderr)
        sys.exit(1)

    prompts = [line[2:] if line.startswith("- ") else line for line in raw]

    if not prompts:
        print("No prompts found.", file=sys.stderr)
        sys.exit(1)

    print(random.choice(prompts))


if __name__ == "__main__":
    main()
