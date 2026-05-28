#!/usr/bin/env python3
"""Lint every .sheet / .fullScreenCover in this repo to ensure modal content
re-injects the LocalizationManager environment.

Why: SwiftUI attaches sheet/fullScreenCover content to the *scene presentation
host*, not to the parent view's view tree. Environment values and view-tree
identity (`.id(...)`) set on the App body therefore do NOT propagate into
the modal. When a user picks a new language via the in-app picker, modal text
stays in the old language until the modal is closed and re-opened. This was
the root cause of five consecutive "lang picker doesn't work" user reports
across the AutoChoice / DaysUntil / AltitudeNow / PromptVault / HabitHash /
FocusFlow apps (CLAUDE.md lesson #34).

The fix pattern, required for every modal:

    .sheet(isPresented: $foo) {
        ChildView()
            .environment(l10n)
            .environment(\\.locale, l10n.currentLocale)
            .id(l10n.override)
    }

Exit 0 on clean, 1 on any violation.
"""
from __future__ import annotations
import re
import sys
from pathlib import Path

MODAL_RE = re.compile(r"\.(sheet|fullScreenCover)\s*\(")
ENV_INJECT_RE = re.compile(r"\.environment\(\s*(?:[a-zA-Z_][a-zA-Z0-9_]*\.)?l10n\b")
SKIP_FRAGMENTS = ("SnapshotHelper.swift",)


def find_close_brace(src: str, open_idx: int) -> int:
    depth = 0
    i = open_idx
    in_str = False
    in_line_cmt = False
    in_block_cmt = False
    while i < len(src):
        c = src[i]
        nxt = src[i + 1] if i + 1 < len(src) else ""
        if in_line_cmt:
            if c == "\n":
                in_line_cmt = False
            i += 1
            continue
        if in_block_cmt:
            if c == "*" and nxt == "/":
                in_block_cmt = False
                i += 2
                continue
            i += 1
            continue
        if in_str:
            if c == "\\":
                i += 2
                continue
            if c == '"':
                in_str = False
            i += 1
            continue
        if c == "/" and nxt == "/":
            in_line_cmt = True
            i += 2
            continue
        if c == "/" and nxt == "*":
            in_block_cmt = True
            i += 2
            continue
        if c == '"':
            in_str = True
            i += 1
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def lint(path: Path) -> list[tuple[int, str, str]]:
    if any(f in str(path) for f in SKIP_FRAGMENTS):
        return []
    try:
        src = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return []
    # Only files presenting a modal need checking. (Do NOT skip files lacking
    # an l10n reference — a modal that *forgot* to inject l10n usually has no
    # l10n reference at all, which is exactly the bug. That skip was a
    # false-negative; fixed 2026-05-29. Non-localized system sheets opt out
    # with a `// l10n-exempt` comment on the modal's opening line.)
    if ".sheet(" not in src and ".fullScreenCover(" not in src:
        return []
    bad: list[tuple[int, str, str]] = []
    for m in MODAL_RE.finditer(src):
        i = m.end()
        paren = 1
        in_str = False
        while i < len(src) and paren > 0:
            c = src[i]
            if in_str:
                if c == "\\":
                    i += 2
                    continue
                if c == '"':
                    in_str = False
            else:
                if c == '"':
                    in_str = True
                elif c == "(":
                    paren += 1
                elif c == ")":
                    paren -= 1
            i += 1
        while i < len(src) and src[i] in " \t\r\n":
            i += 1
        if i >= len(src) or src[i] != "{":
            continue
        close = find_close_brace(src, i)
        if close < 0:
            continue
        body = src[i + 1 : close]
        if ENV_INJECT_RE.search(body):
            continue
        line_start = src.rfind("\n", 0, m.start()) + 1
        line_end = src.find("\n", m.start())
        modal_line = src[line_start : line_end if line_end != -1 else len(src)]
        if "l10n-exempt" in modal_line:
            continue
        line = src.count("\n", 0, m.start()) + 1
        snippet = body.strip().splitlines()[0][:80] if body.strip() else "(empty)"
        bad.append((line, m.group(1), snippet))
    return bad


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    violations = 0
    for swift in root.rglob("*.swift"):
        for line, kind, snippet in lint(swift):
            print(f"{swift}:{line}  .{kind} missing .environment(l10n)  | {snippet}")
            violations += 1
    if violations:
        print()
        print(
            f"FAIL: {violations} violation(s). Each modal needs:\n"
            "  .sheet(isPresented: $x) {\n"
            "      ChildView()\n"
            "          .environment(l10n)\n"
            "          .environment(\\.locale, l10n.currentLocale)\n"
            "          .id(l10n.override)\n"
            "  }"
        )
        return 1
    print("OK: 0 modal env-injection violations.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
