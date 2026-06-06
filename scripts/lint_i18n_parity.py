#!/usr/bin/env python3
"""Verify Localizable.strings key-set parity across all 8 FocusFlow locales,
flag duplicate keys, and confirm every value is a well-formed quoted entry.

Exit 0 on full parity + no dups; 1 otherwise.
"""
from __future__ import annotations
import re
import sys
from pathlib import Path

RES = Path(__file__).resolve().parent.parent / "FocusFlow" / "Resources"
LOCALES = ["en", "ja", "zh-Hans", "zh-Hant", "ko", "es", "fr", "de"]

ENTRY_RE = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', re.MULTILINE)
KEY_RE = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=', re.MULTILINE)


def parse(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    return {m.group(1): m.group(2) for m in ENTRY_RE.finditer(text)}


def all_keys(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    return KEY_RE.findall(text)


def main() -> int:
    ref = parse(RES / "en.lproj" / "Localizable.strings")
    print(f"en key count: {len(ref)}")
    ok = True
    for loc in LOCALES:
        path = RES / f"{loc}.lproj" / "Localizable.strings"
        parsed = parse(path)
        keys = all_keys(path)
        missing = set(ref) - set(parsed)
        extra = set(parsed) - set(ref)
        seen: set[str] = set()
        dups: set[str] = set()
        for k in keys:
            if k in seen:
                dups.add(k)
            seen.add(k)
        # A well-formed entry count must equal the raw key count (no malformed lines).
        malformed = len(keys) - len(parsed) - (len(keys) - len(set(keys)))
        status = "OK" if not (missing or extra or dups or malformed) else "MISMATCH"
        if status != "OK":
            ok = False
        print(f"{loc}: entries={len(parsed)} raw_keys={len(keys)} "
              f"missing={len(missing)} extra={len(extra)} dups={len(dups)} "
              f"malformed={malformed} -> {status}")
        if missing:
            print("   MISSING:", sorted(missing))
        if extra:
            print("   EXTRA:", sorted(extra))
        if dups:
            print("   DUPLICATE:", sorted(dups))
    print("PARITY", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
